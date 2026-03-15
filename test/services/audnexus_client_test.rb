# frozen_string_literal: true

require "test_helper"

class AudnexusClientTest < ActiveSupport::TestCase
  test "search returns results" do
    stub_audible_search(["B017V4IM1G"])
    stub_audnexus_book("B017V4IM1G", book_data)

    results = AudnexusClient.search("harry potter")

    assert_equal 1, results.size
    result = results.first
    assert_equal "B017V4IM1G", result.asin
    assert_equal "Harry Potter and the Sorcerer's Stone, Book 1", result.title
    assert_equal "J.K. Rowling", result.author
    assert_equal "Jim Dale", result.narrator
    assert_equal 498, result.duration_minutes
    assert_equal "Harry Potter", result.series_name
    assert_equal "1", result.series_position
    assert_equal 2015, result.year
    assert_equal "https://m.media-amazon.com/images/I/91eopoUCjLL.jpg", result.cover_url
  end

  test "search returns empty array when no audible results" do
    stub_audible_search([])

    results = AudnexusClient.search("nonexistent book")
    assert_equal [], results
  end

  test "search skips unavailable ASINs" do
    stub_audible_search(["B000MISSING", "B017V4IM1G"])

    stub_request(:get, "https://api.audnex.us/books/B000MISSING")
      .to_return(status: 404, body: { "error" => { "code" => "NOT_FOUND" } }.to_json, headers: { "Content-Type" => "application/json" })

    stub_audnexus_book("B017V4IM1G", book_data)

    results = AudnexusClient.search("harry potter")
    assert_equal 1, results.size
    assert_equal "B017V4IM1G", results.first.asin
  end

  test "search with author parameter" do
    stub_request(:get, /api\.audible\.com\/1\.0\/catalog\/products/)
      .with(query: hash_including("author" => "Rowling"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "products" => [{ "asin" => "B017V4IM1G" }] }.to_json
      )

    stub_audnexus_book("B017V4IM1G", book_data)

    results = AudnexusClient.search("harry potter", author: "Rowling")
    assert_equal 1, results.size
  end

  test "book returns details by ASIN" do
    stub_audnexus_book("B017V4IM1G", book_data)

    result = AudnexusClient.book("B017V4IM1G")

    assert_equal "B017V4IM1G", result.asin
    assert_equal "Jim Dale", result.narrator
    assert_equal "Pottermore Publishing", result.publisher
  end

  test "book returns nil for missing ASIN" do
    stub_request(:get, "https://api.audnex.us/books/B000MISSING")
      .to_return(status: 404, body: { "error" => { "code" => "NOT_FOUND" } }.to_json, headers: { "Content-Type" => "application/json" })

    result = AudnexusClient.book("B000MISSING")
    assert_nil result
  end

  test "test_connection returns true when API is reachable" do
    stub_request(:get, "https://api.audnex.us/books/B017V4IM1G")
      .to_return(status: 200, body: book_data.to_json, headers: { "Content-Type" => "application/json" })

    assert AudnexusClient.test_connection
  end

  test "test_connection returns false when API is unreachable" do
    stub_request(:get, "https://api.audnex.us/books/B017V4IM1G")
      .to_timeout

    refute AudnexusClient.test_connection
  end

  private

  def stub_audible_search(asins)
    products = asins.map { |asin| { "asin" => asin } }
    stub_request(:get, /api\.audible\.com\/1\.0\/catalog\/products/)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "products" => products }.to_json
      )
  end

  def stub_audnexus_book(asin, data)
    stub_request(:get, "https://api.audnex.us/books/#{asin}")
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: data.to_json
      )
  end

  def book_data
    {
      "asin" => "B017V4IM1G",
      "title" => "Harry Potter and the Sorcerer's Stone, Book 1",
      "authors" => [{ "asin" => "B000AP9A6K", "name" => "J.K. Rowling" }],
      "narrators" => [{ "name" => "Jim Dale" }],
      "publisherName" => "Pottermore Publishing",
      "summary" => "Jim Dale's Grammy Award-winning performance...",
      "releaseDate" => "2015-11-20T00:00:00.000Z",
      "image" => "https://m.media-amazon.com/images/I/91eopoUCjLL.jpg",
      "runtimeLengthMin" => 498,
      "seriesPrimary" => { "asin" => "B0182NWM9I", "name" => "Harry Potter", "position" => "1" },
      "language" => "english",
      "genres" => [{ "asin" => "18572091011", "name" => "Children's Audiobooks", "type" => "genre" }]
    }
  end
end
