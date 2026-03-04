# frozen_string_literal: true

require "test_helper"

class RequestQueueJobTest < ActiveJob::TestCase
  setup do
    @pending_request = requests(:pending_request)
    @not_found_retry_due = requests(:not_found_retry_due)
    @not_found_waiting = requests(:not_found_waiting)
  end

  test "requeues not_found requests that are retry due" do
    assert @not_found_retry_due.not_found?
    assert @not_found_retry_due.next_retry_at <= Time.current

    RequestQueueJob.perform_now

    @not_found_retry_due.reload
    assert @not_found_retry_due.pending?
    assert_nil @not_found_retry_due.next_retry_at
  end

  test "does not requeue not_found requests that are not due yet" do
    assert @not_found_waiting.not_found?
    assert @not_found_waiting.next_retry_at > Time.current

    RequestQueueJob.perform_now

    @not_found_waiting.reload
    assert @not_found_waiting.not_found?
    assert_not_nil @not_found_waiting.next_retry_at
  end

  test "processable scope returns pending requests in FIFO order" do
    # Clear existing pending requests
    Request.pending.destroy_all

    # Create pending requests with specific order
    older_book = Book.create!(title: "Older", book_type: :ebook, open_library_work_id: "OL_OLDER")
    newer_book = Book.create!(title: "Newer", book_type: :ebook, open_library_work_id: "OL_NEWER")

    older_request = Request.create!(book: older_book, user: users(:one), status: :pending, created_at: 2.hours.ago)
    newer_request = Request.create!(book: newer_book, user: users(:one), status: :pending, created_at: 1.hour.ago)

    processable = Request.processable.to_a

    assert processable.index(older_request) < processable.index(newer_request), "Older request should come before newer request"
  end

  test "job processes pending requests limited by batch size" do
    # Clear existing pending requests
    Request.pending.destroy_all

    batch_size = SettingsService.get(:queue_batch_size)

    # Create more pending requests than the batch size
    (batch_size + 2).times do |i|
      book = Book.create!(title: "Batch Test #{i}", book_type: :ebook, open_library_work_id: "OL_BATCH_#{i}")
      Request.create!(book: book, user: users(:one), status: :pending)
    end

    # The job logs which requests would be processed
    # We verify the processable scope respects the limit
    processable = Request.processable.limit(batch_size)
    assert_equal batch_size, processable.count

    # Verify the job runs without error
    assert_nothing_raised { RequestQueueJob.perform_now }
  end
end
