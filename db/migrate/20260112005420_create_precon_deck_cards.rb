class CreatePreconDeckCards < ActiveRecord::Migration[8.1]
  def change
    create_table :precon_deck_cards do |t|
      t.references :precon_deck, null: false, foreign_key: true
      t.references :magic_card, null: false, foreign_key: true
      t.integer :quantity, default: 1
      t.string :board_type, null: false
      t.boolean :is_foil, default: false

      t.timestamps
    end

    add_index :precon_deck_cards, [:precon_deck_id, :magic_card_id, :board_type],
              unique: true, name: 'idx_precon_deck_cards_unique'
  end
end
