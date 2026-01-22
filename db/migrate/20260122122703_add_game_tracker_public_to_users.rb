class AddGameTrackerPublicToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :game_tracker_public, :boolean, default: false, null: false
  end
end
