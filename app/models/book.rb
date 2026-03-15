class Book < ApplicationRecord
  has_many :requests, dependent: :restrict_with_error
  has_many :uploads, dependent: :nullify

  validates :title, presence: true

  scope :acquired, -> { where.not(file_path: nil) }
  scope :pending, -> { where(file_path: nil) }

  def acquired?
    file_path.present?
  end

  def display_name
    author.present? ? "#{title} by #{author}" : title
  end

  def formatted_duration
    return nil unless duration_minutes.present? && duration_minutes > 0
    hours = duration_minutes / 60
    mins = duration_minutes % 60
    hours > 0 ? "#{hours}h #{mins}m" : "#{mins}m"
  end

  # Returns unified work_id in format "source:id"
  def unified_work_id
    if asin.present?
      "audnexus:#{asin}"
    elsif hardcover_id.present?
      "hardcover:#{hardcover_id}"
    elsif open_library_work_id.present?
      "openlibrary:#{open_library_work_id}"
    end
  end

  # Parse a work_id into [source, source_id]
  def self.parse_work_id(work_id)
    parts = work_id.to_s.split(":", 2)
    if parts.length == 2
      parts
    else
      # Legacy OpenLibrary IDs without prefix
      [ "openlibrary", work_id ]
    end
  end

  # Find a book by work_id
  def self.find_by_work_id(work_id)
    source, source_id = parse_work_id(work_id)
    case source
    when "audnexus"
      find_by(asin: source_id)
    when "hardcover"
      find_by(hardcover_id: source_id)
    else
      find_by(open_library_work_id: source_id)
    end
  end

  # Find or initialize a book by work_id
  def self.find_or_initialize_by_work_id(work_id)
    source, source_id = parse_work_id(work_id)
    case source
    when "audnexus"
      find_or_initialize_by(asin: source_id)
    when "hardcover"
      find_or_initialize_by(hardcover_id: source_id)
    else
      find_or_initialize_by(open_library_work_id: source_id)
    end
  end
end
