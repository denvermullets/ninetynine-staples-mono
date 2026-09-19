# Whether the item asked for copies its owner had not put on their trade list when it was proposed.
# A snapshot like the prices: the trade list moves afterwards, and the trade page still has to say
# what was being asked of whom at the time.
class AddOffListToTradeItems < ActiveRecord::Migration[8.1]
  def change
    add_column :trade_items, :off_list, :boolean, default: false, null: false
  end
end
