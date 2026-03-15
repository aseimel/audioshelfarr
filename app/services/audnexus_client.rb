# frozen_string_literal: true

# Client for searching audiobooks via the Audible catalog API and enriching
# results with metadata from Audnexus (the same pipeline Audiobookshelf uses).
#
# Flow:
#   1. Search Audible catalog → list of ASINs
#   2. For each ASIN, fetch full metadata from Audnexus
#
# Both APIs are free and require no authentication.
class AudnexusClient
  AUDIBLE_BASE_URL = "https://api.audible.com"
  AUDNEXUS_BASE_URL = "https://api.audnex.us"

  class Error < StandardError; end
  class ConnectionError < Error; end
  class NotFoundError < Error; end
  class RateLimitError < Error; end

  SearchResult = Data.define(
    :asin, :title, :author, :narrator, :description, :year,
    :cover_url, :duration_minutes, :series_name, :series_position,
    :publisher, :language
  )

  class << self
    # Search for audiobooks by title/author.
    # Returns array of SearchResult.
    def search(title, author: nil, limit: 10)
      asins = search_audible(title, author: author, limit: limit)
      return [] if asins.empty?

      asins.filter_map { |asin| fetch_and_parse(asin) }
    end

    # Get book details by ASIN. Returns SearchResult or nil.
    def book(asin)
      fetch_and_parse(asin)
    end

    # Simple connectivity test.
    def test_connection
      response = audnexus_connection.get("/books/B017V4IM1G")
      response.status == 200
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError
      false
    end

    private

    # Step 1: Search Audible catalog for ASINs
    def search_audible(title, author: nil, limit: 10)
      params = {
        num_results: limit.to_s,
        products_sort_by: "Relevance",
        title: title
      }
      params[:author] = author if author.present?

      response = request(:audible) { audible_connection.get("/1.0/catalog/products", params) }

      handle_response(response) do |data|
        Array(data["products"]).filter_map { |p| p["asin"] }
      end
    rescue Error => e
      Rails.logger.error "[AudnexusClient] Audible search failed: #{e.message}"
      []
    end

    # Step 2: Fetch full metadata from Audnexus
    def fetch_and_parse(asin)
      response = request(:audnexus) { audnexus_connection.get("/books/#{URI.encode_uri_component(asin.upcase)}") }

      handle_response(response) do |data|
        parse_result(data)
      end
    rescue NotFoundError
      nil
    rescue Error => e
      Rails.logger.warn "[AudnexusClient] Failed to fetch ASIN #{asin}: #{e.message}"
      nil
    end

    def parse_result(data)
      SearchResult.new(
        asin: data["asin"],
        title: data["title"],
        author: Array(data["authors"]).map { |a| a["name"] }.join(", ").presence,
        narrator: Array(data["narrators"]).map { |n| n["name"] }.join(", ").presence,
        description: data["summary"] || data["description"],
        year: parse_year(data["releaseDate"]),
        cover_url: data["image"],
        duration_minutes: data["runtimeLengthMin"],
        series_name: data.dig("seriesPrimary", "name"),
        series_position: data.dig("seriesPrimary", "position"),
        publisher: data["publisherName"],
        language: data["language"]
      )
    end

    def parse_year(date_string)
      return nil if date_string.blank?
      match = date_string.to_s.match(/\b(19\d{2}|20[0-2]\d)\b/)
      match ? match[1].to_i : nil
    end

    def request(source)
      yield
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
      label = source == :audible ? "Audible" : "Audnexus"
      raise ConnectionError, "Failed to connect to #{label}: #{e.message}"
    end

    def handle_response(response)
      case response.status
      when 200
        yield response.body
      when 404
        raise NotFoundError, "Resource not found"
      when 429
        raise RateLimitError, "Rate limit exceeded"
      else
        raise Error, "API request failed with status #{response.status}"
      end
    end

    def audible_connection
      @audible_connection ||= Faraday.new(url: AUDIBLE_BASE_URL) do |f|
        f.request :url_encoded
        f.response :json, parser_options: { symbolize_names: false }
        f.adapter Faraday.default_adapter
        f.options.timeout = 15
        f.options.open_timeout = 5
      end
    end

    def audnexus_connection
      @audnexus_connection ||= Faraday.new(url: AUDNEXUS_BASE_URL) do |f|
        f.request :url_encoded
        f.response :json, parser_options: { symbolize_names: false }
        f.adapter Faraday.default_adapter
        f.headers["User-Agent"] = "Shelfarr/1.0"
        f.options.timeout = 15
        f.options.open_timeout = 5
      end
    end
  end
end
