# frozen_string_literal: true

require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @admin = users(:two)
    @acquired_audiobook = books(:audiobook_acquired)
    sign_in_as(@user)
  end

  test "index requires authentication" do
    sign_out
    get library_index_path
    assert_response :redirect
  end

  test "index shows acquired books" do
    get library_index_path
    assert_response :success
    assert_select "h1", "Library"
    assert_select "a[href='#{library_path(@acquired_audiobook)}']"
  end

  test "index filters by audiobook type" do
    get library_index_path(type: "audiobook")
    assert_response :success
    assert_select "a[href='#{library_path(@acquired_audiobook)}']"
  end

  test "index filters by ebook type" do
    ebook = Book.create!(
      title: "Acquired Ebook",
      author: "Test Author",
      book_type: :ebook,
      file_path: "/ebooks/Test Author/Acquired Ebook"
    )

    get library_index_path(type: "ebook")
    assert_response :success
    assert_select "a[href='#{library_path(ebook)}']"
  end

  test "index shows empty state when no books" do
    Book.where.not(file_path: nil).update_all(file_path: nil)

    get library_index_path
    assert_response :success
    assert_select "h3", "Your library is empty"
  end

  test "show displays book details" do
    get library_path(@acquired_audiobook)
    assert_response :success
    assert_select "h1", @acquired_audiobook.title
  end

  test "show returns 404 for non-acquired book" do
    pending_book = books(:ebook_pending)

    get library_path(pending_book)
    assert_response :not_found
  end

  test "show displays download button when user has request" do
    request = Request.create!(
      book: @acquired_audiobook,
      user: @user,
      status: :completed
    )

    get library_path(@acquired_audiobook)
    assert_response :success
    assert_select "a[href='#{download_request_path(request)}']", text: /Download/
  end

  test "show does not display download button when user has no request" do
    get library_path(@acquired_audiobook)
    assert_response :success
    assert_select "a[href*='download']", false
  end

  test "show displays file path for admin" do
    sign_out
    sign_in_as(@admin)

    get library_path(@acquired_audiobook)
    assert_response :success
    assert_select "code", @acquired_audiobook.file_path
  end

  test "show does not display file path for regular user" do
    get library_path(@acquired_audiobook)
    assert_response :success
    assert_select "code", false
  end
end
