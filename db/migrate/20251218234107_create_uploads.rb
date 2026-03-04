class CreateUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :uploads do |t|
      t.references :user, null: false, foreign_key: true
      t.references :book, null: true, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :original_filename
      t.string :file_path

      t.timestamps
    end

    add_index :uploads, :status
  end
end
