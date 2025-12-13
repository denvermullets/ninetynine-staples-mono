class AddCollectionHistoryToCollections < ActiveRecord::Migration[8.1]
  def change
    add_column :collections, :collection_history, :jsonb, default: {}
  end
end
