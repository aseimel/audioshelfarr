class AddAsinAndDurationToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :asin, :string
    add_column :books, :duration_minutes, :integer
    add_index :books, :asin
  end
end
