# frozen_string_literal: true

class RequestQueueJob < ApplicationJob
  queue_as :default

  def perform
    requeue_retry_due_requests
    process_pending_requests
  end

  private

  # Re-queue not_found requests that are due for retry
  def requeue_retry_due_requests
    Request.retry_due.find_each do |request|
      Rails.logger.info "[RequestQueueJob] Re-queuing request ##{request.id} for retry (attempt #{request.retry_count + 1})"
      request.requeue!
    end
  end

  # Pick up pending requests in FIFO order, limited by batch size
  def process_pending_requests
    batch_size = SettingsService.get(:queue_batch_size)
    requests = Request.processable.limit(batch_size)

    Rails.logger.info "[RequestQueueJob] Processing #{requests.count} pending requests (batch_size: #{batch_size})"

    requests.each do |request|
      enqueue_search(request)
    end
  end

  # Enqueue the search job for a pending request
  def enqueue_search(request)
    SearchJob.perform_later(request.id)
    Rails.logger.info "[RequestQueueJob] Enqueued SearchJob for request ##{request.id} (book: #{request.book.title})"
  end
end
