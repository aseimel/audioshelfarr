class RemoveEbookFeatures < ActiveRecord::Migration[8.1]
  def change
    # Remove book_type from books table (all books are now audiobooks)
    remove_index :books, :book_type, if_exists: true
    remove_column :books, :book_type, :integer

    # Remove book_type from uploads table
    remove_index :uploads, :book_type, if_exists: true
    remove_column :uploads, :book_type, :integer

    # Remove ebook-related settings
    Setting.where(key: %w[
      ebook_output_path
      ebook_path_template
      ebook_filename_template
      audiobookshelf_ebook_library_id
      anna_archive_enabled
      anna_archive_url
      anna_archive_api_key
      flaresolverr_url
    ]).delete_all
  end
end
