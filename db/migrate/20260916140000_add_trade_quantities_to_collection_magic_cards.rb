class AddTradeQuantitiesToCollectionMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :collection_magic_cards, :trade_quantity, :integer, default: 0, null: false
    add_column :collection_magic_cards, :trade_foil_quantity, :integer, default: 0, null: false
  end
end
