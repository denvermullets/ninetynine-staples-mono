class CreatePreconDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :precon_decks do |t|
      t.string :code, null: false
      t.string :file_name, null: false
      t.string :name, null: false
      t.date :release_date
      t.string :deck_type
      t.boolean :cards_ingested, default: false

      t.timestamps
    end

    add_index :precon_decks, :code
    add_index :precon_decks, :file_name, unique: true
    add_index :precon_decks, :deck_type
  end
end
