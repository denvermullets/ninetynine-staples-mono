class RemoveWorthUpgradingFromTrackedDecks < ActiveRecord::Migration[8.1]
  def change
    remove_column :tracked_decks, :worth_upgrading, :boolean, default: false
  end
end
