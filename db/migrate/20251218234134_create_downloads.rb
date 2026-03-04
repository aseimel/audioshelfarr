class CreateDownloads < ActiveRecord::Migration[8.1]
  def change
    create_table :downloads do |t|
      t.references :request, null: false, foreign_key: true
      t.string :download_client_id
      t.string :name
      t.integer :status, null: false, default: 0
      t.integer :progress, default: 0
      t.bigint :size_bytes
      t.string :download_path

      t.timestamps
    end

    add_index :downloads, :status
    add_index :downloads, :download_client_id
  end
end
