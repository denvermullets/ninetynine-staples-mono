class AddPriceChangeWeeklyToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :price_change_weekly, :decimal, precision: 10, scale: 2
    add_index :magic_cards, :price_change_weekly
  end
end
