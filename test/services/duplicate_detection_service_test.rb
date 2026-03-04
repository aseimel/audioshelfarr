# frozen_string_literal: true

require "test_helper"

class DuplicateDetectionServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "allows request for new work" do
    result = DuplicateDetectionService.check(
      work_id: "OL_NEW_WORK"
    )

    assert result.allow?
    assert_nil result.message
    assert_nil result.existing_book
  end

  test "blocks request for same work already acquired" do
    book = Book.create!(
      title: "Existing Book",
      open_library_work_id: "OL_ACQUIRED",
      file_path: "/audiobooks/Author/Book"
    )

    result = DuplicateDetectionService.check(
      work_id: "OL_ACQUIRED"
    )

    assert result.block?
    assert_includes result.message, "already in your library"
    assert_equal book, result.existing_book
  end

  test "blocks request for same edition already acquired" do
    book = Book.create!(
      title: "Existing Book",
      open_library_work_id: "OL_WORK",
      open_library_edition_id: "OL_EDITION",
      file_path: "/audiobooks/Book"
    )

    result = DuplicateDetectionService.check(
      work_id: "OL_WORK",
      edition_id: "OL_EDITION"
    )

    assert result.block?
    assert_includes result.message, "exact edition"
    assert_equal book, result.existing_book
  end

  test "blocks request when active request exists" do
    book = Book.create!(
      title: "Pending Book",
      open_library_work_id: "OL_PENDING"
    )

    request = Request.create!(
      book: book,
      user: @user,
      status: :pending
    )

    result = DuplicateDetectionService.check(
      work_id: "OL_PENDING"
    )

    assert result.block?
    assert_includes result.message, "active request"
    assert_equal book, result.existing_book
    assert_equal request, result.existing_request
  end

  test "warns when previous request failed" do
    book = Book.create!(
      title: "Failed Book",
      open_library_work_id: "OL_FAILED"
    )

    Request.create!(
      book: book,
      user: @user,
      status: :failed
    )

    result = DuplicateDetectionService.check(
      work_id: "OL_FAILED"
    )

    assert result.warn?
    assert_includes result.message, "failed"
  end

  test "warns when previous request was not found" do
    book = Book.create!(
      title: "Not Found Book",
      open_library_work_id: "OL_NOT_FOUND"
    )

    Request.create!(
      book: book,
      user: @user,
      status: :not_found
    )

    result = DuplicateDetectionService.check(
      work_id: "OL_NOT_FOUND"
    )

    assert result.warn?
    assert_includes result.message, "not found"
  end

  test "can_request? returns true for allowed" do
    assert DuplicateDetectionService.can_request?(
      work_id: "OL_BRAND_NEW"
    )
  end

  test "can_request? returns true for warned" do
    Book.create!(
      title: "Previously Failed",
      open_library_work_id: "OL_WARN"
    )

    Request.create!(
      book: Book.find_by(open_library_work_id: "OL_WARN"),
      user: @user,
      status: :failed
    )

    assert DuplicateDetectionService.can_request?(
      work_id: "OL_WARN"
    )
  end

  test "can_request? returns false for blocked" do
    Book.create!(
      title: "Acquired",
      open_library_work_id: "OL_BLOCKED",
      file_path: "/audiobooks/Book"
    )

    refute DuplicateDetectionService.can_request?(
      work_id: "OL_BLOCKED"
    )
  end
end
