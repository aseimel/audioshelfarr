class AddIndexToSearchResultsStatus < ActiveRecord::Migration[8.1]
  def change
    add_index :search_results, :status
  end
end
