class AddPriceHistoryToMagicCards < ActiveRecord::Migration[7.2]
  def change
    add_column :magic_cards, :price_history, :jsonb
  end
end
