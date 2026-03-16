class CreateGameChangers < ActiveRecord::Migration[8.1]
  def change
    create_table :game_changers do |t|
      t.uuid :oracle_id, null: false
      t.string :card_name, null: false
      t.text :reason

      t.timestamps
    end
    add_index :game_changers, :oracle_id, unique: true
  end
end
