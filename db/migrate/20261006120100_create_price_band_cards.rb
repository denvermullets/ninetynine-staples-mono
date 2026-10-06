# Where each card a price band watches sits relative to the band, one row per printing and finish.
# The listed rows nobody has handled yet are the band's worklist. See PriceBandCard.
class CreatePriceBandCards < ActiveRecord::Migration[8.1]
  def change
    create_table :price_band_cards do |t|
      t.references :price_alert, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :magic_card, null: false, foreign_key: { on_delete: :cascade }
      t.string :finish, null: false
      t.string :state, null: false
      t.date :crossed_on
      t.decimal :crossed_price, precision: 10, scale: 2
      t.string :moved
      t.datetime :handled_at

      t.timestamps
    end

    add_index :price_band_cards, %i[price_alert_id magic_card_id finish], unique: true,
                                                                          name: 'index_price_band_cards_on_band_card_finish'
  end
end
