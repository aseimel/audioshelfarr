# frozen_string_literal: true

# Unified service for fetching audiobook metadata from Audible/Audnexus.
# Uses the same pipeline as Audiobookshelf: Audible catalog search + Audnexus enrichment.
class MetadataService
  class Error < StandardError; end

  # Unified result structure
  SearchResult = Data.define(
    :source, :source_id, :title, :author, :description, :year,
    :cover_url, :series_name, :narrator, :duration_minutes
  ) do
    def work_id
      "#{source}:#{source_id}"
    end

    # Compatibility with view patterns
    def first_publish_year
      year
    end

    def cover_id
      nil
    end
  end

  class << self
    # Search for audiobooks. Returns array of SearchResult.
    def search(query, limit: 10)
      Rails.logger.info "[MetadataService] Searching '#{query}' via Audible/Audnexus"

      # Parse query into title/author if possible
      title, author = parse_query(query)
      results = AudnexusClient.search(title, author: author, limit: limit)
      results.map { |r| normalize_result(r) }
    rescue AudnexusClient::Error => e
      Rails.logger.error "[MetadataService] Search failed: #{e.message}"
      []
    end

    # Get book details by unified work_id (format: "audnexus:{asin}")
    def book_details(work_id)
      source, id = parse_work_id(work_id)

      Rails.logger.info "[MetadataService] Fetching details for #{work_id}"

      case source
      when "audnexus"
        result = AudnexusClient.book(id)
        result ? normalize_result(result) : raise(Error, "Book not found: #{id}")
      else
        raise ArgumentError, "Unknown metadata source: #{source}"
      end
    end

    # Test metadata source connectivity
    def test_connections
      {
        audnexus: begin
          AudnexusClient.test_connection
        rescue
          false
        end
      }
    end

    # Always available (no config needed)
    def available?
      true
    end

    private

    def normalize_result(result)
      SearchResult.new(
        source: "audnexus",
        source_id: result.asin,
        title: result.title,
        author: result.author,
        description: truncate_description(result.description),
        year: result.year,
        cover_url: result.cover_url,
        series_name: result.series_name,
        narrator: result.narrator,
        duration_minutes: result.duration_minutes
      )
    end

    def parse_work_id(work_id)
      Book.parse_work_id(work_id)
    end

    # Try to split a search query into title and author.
    # Users often search "Title Author" or just "Title".
    def parse_query(query)
      # For now, pass the full query as title and let Audible handle it
      [query, nil]
    end

    def truncate_description(desc)
      return nil if desc.blank?
      # Strip HTML tags from Audnexus summaries
      cleaned = ActionController::Base.helpers.strip_tags(desc)
      cleaned.length > 500 ? "#{cleaned[0, 497]}..." : cleaned
    end
  end
end
