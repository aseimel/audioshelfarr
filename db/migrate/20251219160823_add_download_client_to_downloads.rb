class AddDownloadClientToDownloads < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:downloads, :download_client_id)
      add_reference :downloads, :download_client, foreign_key: true
    end
  end
end
