class AddTotalCardsToCollection < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :total_foil_quantity, :integer, default: 0
    add_column :collections, :total_quantity, :integer, default: 0
  end
end
