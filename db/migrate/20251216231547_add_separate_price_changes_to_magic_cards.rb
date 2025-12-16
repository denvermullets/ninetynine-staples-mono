class AddSeparatePriceChangesToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :price_change_weekly_normal, :decimal, precision: 10, scale: 2
    add_column :magic_cards, :price_change_weekly_foil, :decimal, precision: 10, scale: 2

    add_index :magic_cards, :price_change_weekly_normal
    add_index :magic_cards, :price_change_weekly_foil

    remove_column :magic_cards, :price_change_weekly, :decimal
  end
end
