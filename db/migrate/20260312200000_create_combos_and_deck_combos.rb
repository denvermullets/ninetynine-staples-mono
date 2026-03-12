class CreateCombosAndDeckCombos < ActiveRecord::Migration[8.0]
  def change
    create_table :combos do |t|
      t.string :spellbook_id, null: false
      t.text :prerequisites
      t.text :steps
      t.text :results
      t.string :color_identity
      t.string :permalink
      t.boolean :has_banned_card, default: false

      t.timestamps
    end

    add_index :combos, :spellbook_id, unique: true

    create_table :combo_cards do |t|
      t.references :combo, null: false, foreign_key: true
      t.string :card_name, null: false
      t.uuid :oracle_id

      t.timestamps
    end

    add_index :combo_cards, :oracle_id

    create_table :deck_combos do |t|
      t.references :collection, null: false, foreign_key: true
      t.references :combo, null: false, foreign_key: true
      t.string :combo_type, null: false

      t.timestamps
    end

    add_index :deck_combos, %i[collection_id combo_id], unique: true

    create_table :deck_combo_missing_cards do |t|
      t.references :deck_combo, null: false, foreign_key: true
      t.string :card_name, null: false
      t.uuid :oracle_id

      t.timestamps
    end

    add_column :collections, :combos_checked_at, :datetime
  end
end
