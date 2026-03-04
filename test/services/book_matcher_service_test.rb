# frozen_string_literal: true

require "test_helper"

class BookMatcherServiceTest < ActiveSupport::TestCase
  setup do
    @audiobook = Book.create!(
      title: "The Final Empire",
      author: "Brandon Sanderson",
      book_type: :audiobook
    )

    @ebook = Book.create!(
      title: "Dune",
      author: "Frank Herbert",
      book_type: :ebook
    )
  end

  test "exact match returns high score" do
    result = BookMatcherService.match(
      title: "The Final Empire",
      author: "Brandon Sanderson",
      book_type: :audiobook
    )

    assert result.exact?
    assert_equal @audiobook, result.book
    assert result.score >= 95
  end

  test "fuzzy match with slight typo" do
    result = BookMatcherService.match(
      title: "The Final Empre",
      author: "Brandon Sanderson",
      book_type: :audiobook
    )

    assert result.fuzzy?
    assert_equal @audiobook, result.book
  end

  test "no match for different book type" do
    result = BookMatcherService.match(
      title: "The Final Empire",
      author: "Brandon Sanderson",
      book_type: :ebook
    )

    assert result.no_match?
    assert_nil result.book
  end

  test "matches without author" do
    result = BookMatcherService.match(
      title: "Dune",
      author: nil,
      book_type: :ebook
    )

    assert_equal @ebook, result.book
  end

  test "find_or_create_book returns existing on match" do
    book = BookMatcherService.find_or_create_book(
      title: "The Final Empire",
      author: "Brandon Sanderson",
      book_type: :audiobook
    )

    assert_equal @audiobook, book
  end

  test "find_or_create_book creates new when no match" do
    assert_difference "Book.count", 1 do
      book = BookMatcherService.find_or_create_book(
        title: "New Book",
        author: "New Author",
        book_type: :ebook
      )

      assert_equal "New Book", book.title
      assert_equal "New Author", book.author
      assert book.ebook?
    end
  end

  test "case insensitive matching" do
    result = BookMatcherService.match(
      title: "THE FINAL EMPIRE",
      author: "BRANDON SANDERSON",
      book_type: :audiobook
    )

    assert result.exact?
    assert_equal @audiobook, result.book
  end

  test "no match for completely different title" do
    result = BookMatcherService.match(
      title: "Completely Different Book",
      author: "Unknown Author",
      book_type: :audiobook
    )

    assert result.no_match?
  end

  test "returns no match for blank title" do
    result = BookMatcherService.match(
      title: "",
      author: "Some Author",
      book_type: :audiobook
    )

    assert result.no_match?
  end
end
