# A user's price alerts: "tell me when this card crosses $X" (threshold) and "tell me when things
# move this much" (movement), either across a collection or for one card. See PriceAlert.
class CreatePriceAlerts < ActiveRecord::Migration[8.1]
  def change
    create_table :price_alerts do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.references :magic_card, foreign_key: true
      t.uuid :scryfall_oracle_id
      t.references :collection, foreign_key: true
      t.string :finish, null: false, default: 'any'
      t.string :direction, null: false
      t.decimal :threshold_price, precision: 10, scale: 2
      t.string :window
      t.decimal :min_delta_amount, precision: 10, scale: 2
      t.decimal :min_delta_percent, precision: 10, scale: 2
      t.decimal :min_price, precision: 10, scale: 2
      t.string :last_side
      t.datetime :last_fired_at
      t.date :last_evaluated_on
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :price_alerts, %i[user_id active]
    add_index :price_alerts, :scryfall_oracle_id
    # one per-card movement override per card and window
    add_index :price_alerts, %i[user_id magic_card_id window], unique: true,
                                                               where: "kind = 'movement' AND magic_card_id IS NOT NULL",
                                                               name: 'index_price_alerts_on_card_override'
  end
end
