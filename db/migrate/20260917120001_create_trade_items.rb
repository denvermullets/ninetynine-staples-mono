class CreateTradeItems < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_items do |t|
      t.references :trade, null: false, foreign_key: true
      # nullable: the owner may delete the collection row after the trade is proposed, and the
      # ledger still has to show what was offered
      t.references :collection_magic_card, foreign_key: true
      t.references :magic_card, null: false, foreign_key: true
      t.string :side, null: false
      t.integer :quantity, null: false, default: 0
      t.integer :foil_quantity, null: false, default: 0
      t.decimal :unit_price_snapshot, precision: 12, scale: 2, default: '0.0'
      t.decimal :unit_foil_price_snapshot, precision: 12, scale: 2, default: '0.0'
      t.decimal :unit_buylist_snapshot, precision: 12, scale: 2, default: '0.0'
      t.decimal :unit_buylist_foil_snapshot, precision: 12, scale: 2, default: '0.0'

      t.timestamps
    end

    add_index :trade_items, %i[trade_id side]
  end
end
