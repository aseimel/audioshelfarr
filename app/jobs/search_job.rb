# frozen_string_literal: true

class SearchJob < ApplicationJob
  queue_as :default

  def perform(request_id, force_auto_select: false)
    @force_auto_select = force_auto_select

    request = Request.find_by(id: request_id)
    return unless request
    return unless request.pending?
    return unless request.book # Guard against orphaned requests

    Rails.logger.info "[SearchJob] Starting search for request ##{request.id} (book: #{request.book.title})"

    request.update!(status: :searching)

    # Check if Prowlarr is configured
    unless ProwlarrClient.configured?
      Rails.logger.error "[SearchJob] No search sources configured"
      request.mark_for_attention!("No search sources configured. Please configure Prowlarr in Admin Settings.")
      return
    end

    begin
      results = search_prowlarr(request)
      Rails.logger.info "[SearchJob] Found #{results.count} Prowlarr results"

      if results.any?
        save_results(request, results)
        Rails.logger.info "[SearchJob] Total #{results.count} results for request ##{request.id}"
        attempt_auto_select(request)
      else
        Rails.logger.info "[SearchJob] No results found for request ##{request.id}"
        request.schedule_retry!
      end
    rescue ProwlarrClient::AuthenticationError => e
      Rails.logger.error "[SearchJob] Prowlarr authentication failed: #{e.message}"
      request.mark_for_attention!("Prowlarr authentication failed. Please check your API key.")
    rescue ProwlarrClient::ConnectionError => e
      Rails.logger.error "[SearchJob] Prowlarr connection error for request ##{request.id}: #{e.message}"
      request.schedule_retry!
    rescue ProwlarrClient::Error => e
      Rails.logger.error "[SearchJob] Prowlarr error for request ##{request.id}: #{e.message}"
      request.schedule_retry!
    end
  end

  private

  def search_prowlarr(request)
    book = request.book
    language_term = should_add_language_to_search?(request) ? language_search_term(request) : nil

    # Try multiple query variations (stop on first results found)
    queries = build_query_variations(book, language_term)

    queries.each do |query|
      Rails.logger.info "[SearchJob] Trying query: #{query}"
      results = ProwlarrClient.search(query)
      if results.any?
        Rails.logger.info "[SearchJob] Found #{results.count} results with query: #{query}"
        return results
      end
    end

    # Fallback: try title-only query WITHOUT category filter to catch audiobooks in unexpected categories
    fallback_query = language_term ? "#{book.title} #{language_term}" : book.title
    Rails.logger.info "[SearchJob] Trying category-less fallback query: #{fallback_query}"
    results = ProwlarrClient.search(fallback_query, categories: [])
    if results.any?
      Rails.logger.info "[SearchJob] Found #{results.count} results with category-less fallback"
      return results
    end

    [] # No results from any query
  end

  def build_query_variations(book, language_term)
    title = book.title
    author = book.author
    short_title = strip_subtitle(title)

    queries = []

    # Variation 1: author + title (most specific)
    if author.present?
      base = "#{author} #{title}"
      queries << (language_term ? "#{base} #{language_term}" : base)
      queries << (language_term ? "#{base} audiobook #{language_term}" : "#{base} audiobook")
    end

    # Variation 2: title + author (reversed)
    if author.present?
      base = "#{title} #{author}"
      queries << (language_term ? "#{base} #{language_term}" : base)
      queries << (language_term ? "#{base} audiobook #{language_term}" : "#{base} audiobook")
    end

    # Variation 3: title only (broader)
    queries << (language_term ? "#{title} #{language_term}" : title)

    # Variation 4: short title + author (stripped subtitle)
    if short_title != title && author.present?
      base = "#{short_title} #{author}"
      queries << (language_term ? "#{base} #{language_term}" : base)
    end

    # Variation 5: short title only
    if short_title != title
      queries << (language_term ? "#{short_title} #{language_term}" : short_title)
    end

    queries.uniq
  end

  def strip_subtitle(title)
    # Strip subtitle after colon or opening paren, like Readarr does
    title.split(/[:(\[]/, 2).first.strip
  end

  def save_results(request, results)
    request.search_results.destroy_all

    results.each do |result|
      search_result = request.search_results.create!(
        guid: result.guid,
        title: result.title,
        indexer: result.indexer,
        size_bytes: result.size_bytes,
        seeders: result.seeders,
        leechers: result.leechers,
        download_url: result.download_url,
        magnet_url: result.magnet_url,
        info_url: result.info_url,
        published_at: result.published_at,
        source: SearchResult::SOURCE_PROWLARR
      )

      search_result.calculate_score!
    end
  end

  def attempt_auto_select(request)
    unless @force_auto_select || SettingsService.get(:auto_select_enabled, default: true)
      # Auto-select disabled, flag for manual selection
      request.mark_for_attention!("Results found. Review and select a result to download.")
      Rails.logger.info "[SearchJob] Auto-select disabled, flagged for manual selection for request ##{request.id}"
      return
    end

    result = AutoSelectService.call(request)

    if result.success?
      Rails.logger.info "[SearchJob] Auto-selected result for request ##{request.id}"
    else
      # Auto-select failed to find a suitable result, flag for manual selection
      request.mark_for_attention!("Results found but none matched auto-select criteria. Select a result manually.")
      Rails.logger.info "[SearchJob] Auto-select failed, flagged for manual selection for request ##{request.id}"
    end
  end

  # Check if we should add language to the search query
  # Only add for non-English languages that we have a name for
  def should_add_language_to_search?(request)
    language = request.effective_language
    return false if language.blank? || language == "en"

    # Only add if we have a known language name
    info = ReleaseParserService.language_info(language)
    info.present?
  end

  # Get the language name for search query
  def language_search_term(request)
    language = request.effective_language
    info = ReleaseParserService.language_info(language)
    info[:name]
  end
end
