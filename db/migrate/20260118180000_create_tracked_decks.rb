class CreateTrackedDecks < ActiveRecord::Migration[8.1]
  def change
    create_table :tracked_decks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :commander, null: false, foreign_key: { to_table: :magic_cards }
      t.references :partner_commander, foreign_key: { to_table: :magic_cards }
      t.string :name, null: false
      t.text :notes
      t.string :status, default: 'active'
      t.boolean :worth_upgrading, default: false
      t.date :last_tweaked_at

      t.timestamps
    end

    add_index :tracked_decks, :status
    add_index :tracked_decks, [:user_id, :name], unique: true
  end
end
