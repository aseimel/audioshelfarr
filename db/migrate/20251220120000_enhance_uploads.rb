# frozen_string_literal: true

class EnhanceUploads < ActiveRecord::Migration[8.0]
  def change
    add_column :uploads, :file_size, :bigint
    add_column :uploads, :content_type, :string
    add_column :uploads, :parsed_title, :string
    add_column :uploads, :parsed_author, :string
    add_column :uploads, :book_type, :integer
    add_column :uploads, :match_confidence, :integer
    add_column :uploads, :error_message, :text
    add_column :uploads, :processed_at, :datetime

    add_index :uploads, :book_type
    add_index :uploads, :processed_at
  end
end
