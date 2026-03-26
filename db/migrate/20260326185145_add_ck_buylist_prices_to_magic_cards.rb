class AddCkBuylistPricesToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :ck_buylist_normal_price, :decimal, precision: 12, scale: 2, default: 0.0
    add_column :magic_cards, :ck_buylist_foil_price, :decimal, precision: 12, scale: 2, default: 0.0
  end
end
