class AddCollectionToTrackedDecks < ActiveRecord::Migration[8.1]
  def change
    add_reference :tracked_decks, :collection, null: true, foreign_key: true
  end
end
