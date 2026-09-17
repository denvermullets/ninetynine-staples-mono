class AddTradesPublicToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :trades_public, :boolean, default: false, null: false
  end
end
