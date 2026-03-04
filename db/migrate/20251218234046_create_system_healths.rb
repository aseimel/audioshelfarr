class CreateSystemHealths < ActiveRecord::Migration[8.1]
  def change
    create_table :system_healths do |t|
      t.string :service, null: false
      t.integer :status, null: false, default: 0
      t.text :message
      t.datetime :last_check_at
      t.datetime :last_success_at

      t.timestamps
    end

    add_index :system_healths, :service, unique: true
    add_index :system_healths, :status
  end
end
