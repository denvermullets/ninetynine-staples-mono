class CreateGameOpponents < ActiveRecord::Migration[8.1]
  def change
    create_table :game_opponents do |t|
      t.references :commander_game, null: false, foreign_key: true
      t.references :commander, null: false, foreign_key: { to_table: :magic_cards }
      t.references :partner_commander, foreign_key: { to_table: :magic_cards }

      t.boolean :won, default: false
      t.string :win_condition
      t.text :how_won

      t.timestamps
    end

    add_index :game_opponents, :won
    add_index :game_opponents, :win_condition
  end
end
