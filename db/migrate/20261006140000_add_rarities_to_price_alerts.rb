# The rarities a movement rule counts, the movers table's rarity filter saved. Empty counts them all.
class AddRaritiesToPriceAlerts < ActiveRecord::Migration[8.1]
  def change
    add_column :price_alerts, :rarities, :string, array: true, default: [], null: false
  end
end
