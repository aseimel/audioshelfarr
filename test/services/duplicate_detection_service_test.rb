# frozen_string_literal: true

require "test_helper"

class DuplicateDetectionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "allows request for new work" do
    result = DuplicateDetectionService.check(
      work_id: "audnexus:B000NEW001"
    )

    assert result.allow?
    assert_nil result.message
    assert_nil result.existing_book
  end

  test "blocks request for same work already acquired" do
    book = Book.create!(
      title: "Existing Book",
      asin: "B000ACQUIRED",
      file_path: "/audiobooks/Author/Book"
    )

    result = DuplicateDetectionService.check(
      work_id: "audnexus:B000ACQUIRED"
    )

    assert result.block?
    assert_includes result.message, "already in your library"
    assert_equal book, result.existing_book
  end

  test "blocks request for same edition already acquired" do
    book = Book.create!(
      title: "Existing Book",
      asin: "B000EDITION",
      file_path: "/audiobooks/Book"
    )

    result = DuplicateDetectionService.check(
      work_id: "audnexus:B000EDITION",
      edition_id: "B000EDITION"
    )

    assert result.block?
    assert_includes result.message, "exact edition"
    assert_equal book, result.existing_book
  end

  test "blocks request when active request exists" do
    book = Book.create!(
      title: "Pending Book",
      asin: "B000PENDING"
    )

    request = Request.create!(
      book: book,
      user: @user,
      status: :pending
    )

    result = DuplicateDetectionService.check(
      work_id: "audnexus:B000PENDING"
    )

    assert result.block?
    assert_includes result.message, "already in the queue"
    assert_equal book, result.existing_book
    assert_equal request, result.existing_request
  end

  test "warns when previous request failed" do
    book = Book.create!(
      title: "Failed Book",
      asin: "B000FAILED"
    )

    Request.create!(
      book: book,
      user: @user,
      status: :failed
    )

    result = DuplicateDetectionService.check(
      work_id: "audnexus:B000FAILED"
    )

    assert result.warn?
    assert_includes result.message, "failed"
  end

  test "warns when previous request was not found" do
    book = Book.create!(
      title: "Not Found Book",
      asin: "B000NOTFOUND"
    )

    Request.create!(
      book: book,
      user: @user,
      status: :not_found
    )

    result = DuplicateDetectionService.check(
      work_id: "audnexus:B000NOTFOUND"
    )

    assert result.warn?
    assert_includes result.message, "not found"
  end

  test "can_request? returns true for allowed" do
    assert DuplicateDetectionService.can_request?(
      work_id: "audnexus:B000BRANDNEW"
    )
  end

  test "can_request? returns true for warned" do
    Book.create!(
      title: "Previously Failed",
      asin: "B000WARN"
    )

    Request.create!(
      book: Book.find_by(asin: "B000WARN"),
      user: @user,
      status: :failed
    )

    assert DuplicateDetectionService.can_request?(
      work_id: "audnexus:B000WARN"
    )
  end

  test "can_request? returns false for blocked" do
    Book.create!(
      title: "Acquired",
      asin: "B000BLOCKED",
      file_path: "/audiobooks/Book"
    )

    refute DuplicateDetectionService.can_request?(
      work_id: "audnexus:B000BLOCKED"
    )
  end
end
