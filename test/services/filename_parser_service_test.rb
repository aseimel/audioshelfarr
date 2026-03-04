# frozen_string_literal: true

require "test_helper"

class FilenameParserServiceTest < ActiveSupport::TestCase
  test "parses Author - Title pattern" do
    result = FilenameParserService.parse("Brandon Sanderson - Mistborn.m4b")

    assert_equal "Mistborn", result.title
    assert_equal "Brandon Sanderson", result.author
    assert_equal :author_dash_title, result.pattern_matched
    assert result.confidence >= 80
  end

  test "parses Title (Author) pattern" do
    result = FilenameParserService.parse("The Final Empire (Brandon Sanderson).epub")

    assert_equal "The Final Empire", result.title
    assert_equal "Brandon Sanderson", result.author
    assert_equal :title_paren_author, result.pattern_matched
  end

  test "parses Title [Author] pattern" do
    result = FilenameParserService.parse("Dune [Frank Herbert].pdf")

    assert_equal "Dune", result.title
    assert_equal "Frank Herbert", result.author
    assert_equal :title_bracket_author, result.pattern_matched
  end

  test "parses underscore_separated pattern" do
    result = FilenameParserService.parse("Frank_Herbert-Dune.m4b")

    assert_equal "Dune", result.title
    assert_equal "Frank Herbert", result.author
  end

  test "handles files with no author pattern" do
    result = FilenameParserService.parse("Some Random Book.epub")

    assert_equal "Some Random Book", result.title
    assert_nil result.author
    assert_equal :fallback, result.pattern_matched
    assert result.confidence < 50
  end

  test "removes year from filename" do
    result = FilenameParserService.parse("Author Name - Book Title (2020).m4b")

    assert_equal "Book Title", result.title
    assert_equal "Author Name", result.author
  end

  test "handles em-dash separator" do
    result = FilenameParserService.parse("Author Name \u2014 Book Title.mp3")

    assert_equal "Book Title", result.title
    assert_equal "Author Name", result.author
  end

  test "normalizes whitespace" do
    result = FilenameParserService.parse("  Author   Name  -  Book   Title  .epub")

    assert_equal "Book Title", result.title
    assert_equal "Author Name", result.author
  end

  test "removes format indicators from filename" do
    result = FilenameParserService.parse("Author Name - Book Title MP3.m4b")

    assert_equal "Book Title", result.title
    assert_equal "Author Name", result.author
  end

  test "removes Unabridged indicator from filename" do
    result = FilenameParserService.parse("Author Name - Book Title - Unabridged.m4b")

    assert_equal "Book Title", result.title
    assert_equal "Author Name", result.author
  end

  test "title cases the output" do
    result = FilenameParserService.parse("brandon sanderson - the final empire.m4b")

    assert_equal "The Final Empire", result.title
    assert_equal "Brandon Sanderson", result.author
  end
end
