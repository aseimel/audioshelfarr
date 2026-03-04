class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.string :author
      t.text :description
      t.string :cover_url
      t.string :isbn
      t.string :open_library_work_id
      t.string :open_library_edition_id
      t.integer :book_type, null: false, default: 0
      t.integer :year
      t.string :publisher
      t.string :language, default: "en"
      t.string :file_path

      t.timestamps
    end

    add_index :books, :isbn
    add_index :books, :open_library_work_id
    add_index :books, :open_library_edition_id
    add_index :books, :book_type
  end
end
