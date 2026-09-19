class AddWantsPublicToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :wants_public, :boolean, default: false, null: false
  end
end
