class CreateCollectionMagicCards < ActiveRecord::Migration[7.2]
  def change
    create_table :collection_magic_cards do |t|
      t.belongs_to :collection, foreign_key: "collection_id", null: false
      t.belongs_to :magic_card, foreign_key: "magic_card_id", null: false
      t.string :card_uuid
      t.integer :foil_quantity, default: 0
      t.integer :quantity, default: 0
      t.decimal :buy_price, precision: 12, scale: 2, default: 0
      t.decimal :sell_price, precision: 12, scale: 2, default: 0
      t.string :condition
      t.text :notes

      t.timestamps
    end
  end
end
