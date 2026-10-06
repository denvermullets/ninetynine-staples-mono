# A Card Kingdom buylist range for movement rules and price bands, and the "from" price a band
# re-arms at. See PriceAlert.
class AddBuylistRangeAndBandToPriceAlerts < ActiveRecord::Migration[8.1]
  def change
    add_column :price_alerts, :min_buylist_price, :decimal, precision: 10, scale: 2
    add_column :price_alerts, :max_buylist_price, :decimal, precision: 10, scale: 2
    add_column :price_alerts, :from_price, :decimal, precision: 10, scale: 2
  end
end
