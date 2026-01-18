class CreateCommanderGames < ActiveRecord::Migration[8.1]
  def change
    create_table :commander_games do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tracked_deck, null: false, foreign_key: true

      t.date :played_on, null: false
      t.boolean :won, default: false, null: false
      t.integer :turn_ended_on
      t.integer :pod_size, default: 4
      t.integer :bracket_level

      t.integer :fun_rating
      t.integer :performance_rating

      t.string :win_condition
      t.text :how_won

      t.text :notes

      t.timestamps
    end

    add_index :commander_games, :played_on
    add_index :commander_games, :won
    add_index :commander_games, :bracket_level
    add_index :commander_games, [:user_id, :played_on]
  end
end
