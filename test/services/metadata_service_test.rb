# frozen_string_literal: true

require "test_helper"

class MetadataServiceTest < ActiveSupport::TestCase
  test "search returns results from audnexus" do
    stub_audible_search(["B017V4IM1G"])
    stub_audnexus_book("B017V4IM1G", audnexus_book_data)

    results = MetadataService.search("harry potter")

    assert results.any?
    assert_equal "audnexus", results.first.source
    assert_equal "B017V4IM1G", results.first.source_id
    assert_equal "Harry Potter and the Sorcerer's Stone, Book 1", results.first.title
    assert_equal "Jim Dale", results.first.narrator
    assert_equal 498, results.first.duration_minutes
  end

  test "search returns empty array when no results" do
    stub_audible_search([])

    results = MetadataService.search("nonexistent book xyz123")
    assert_equal [], results
  end

  test "book_details handles audnexus work_id" do
    stub_audnexus_book("B017V4IM1G", audnexus_book_data)

    result = MetadataService.book_details("audnexus:B017V4IM1G")

    assert_equal "audnexus", result.source
    assert_equal "Harry Potter and the Sorcerer's Stone, Book 1", result.title
  end

  test "book_details raises for unknown source" do
    assert_raises(ArgumentError) do
      MetadataService.book_details("unknown:123")
    end
  end

  test "SearchResult has unified interface" do
    result = MetadataService::SearchResult.new(
      source: "audnexus",
      source_id: "B017V4IM1G",
      title: "Test Book",
      author: "Test Author",
      description: "Description",
      year: 2020,
      cover_url: "https://example.com/cover.jpg",
      series_name: "Test Series",
      narrator: "Test Narrator",
      duration_minutes: 600
    )

    assert_equal "audnexus:B017V4IM1G", result.work_id
    assert_equal 2020, result.first_publish_year
    assert_nil result.cover_id
    assert_equal "Test Narrator", result.narrator
    assert_equal 600, result.duration_minutes
  end

  test "available? always returns true" do
    assert MetadataService.available?
  end

  test "test_connections returns audnexus status" do
    stub_request(:get, "https://api.audnex.us/books/B017V4IM1G")
      .to_return(status: 200, body: audnexus_book_data.to_json, headers: { "Content-Type" => "application/json" })

    results = MetadataService.test_connections
    assert results.key?(:audnexus)
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

  def audnexus_book_data
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
