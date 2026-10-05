# Day-over-day percentage moves, same shape as the weekly pair. Existing rows fill in from
# BackfillPriceChangeDaily, new ones on the next IngestPrices run.
class AddPriceChangeDailyToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :price_change_daily_normal, :decimal, precision: 10, scale: 2
    add_column :magic_cards, :price_change_daily_foil, :decimal, precision: 10, scale: 2

    add_index :magic_cards, :price_change_daily_normal
    add_index :magic_cards, :price_change_daily_foil
  end
end
