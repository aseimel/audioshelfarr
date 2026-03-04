# frozen_string_literal: true

class Upload < ApplicationRecord
  belongs_to :user
  belongs_to :book, optional: true

  enum :status, {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  # Supported file extensions for audiobooks
  SUPPORTED_EXTENSIONS = %w[m4b mp3 zip rar].freeze

  validates :original_filename, presence: true
  validates :status, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :pending_or_processing, -> { where(status: [:pending, :processing]) }

  def file_extension
    File.extname(original_filename).delete(".").downcase
  end

  def archive_file?
    %w[zip rar].include?(file_extension)
  end

  def display_status
    case status
    when "pending" then "Waiting to process"
    when "processing" then "Processing..."
    when "completed" then "Completed"
    when "failed" then "Failed: #{error_message}"
    end
  end
end
