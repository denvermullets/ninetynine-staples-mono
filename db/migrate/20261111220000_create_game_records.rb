# The finished GameRecord of a network game, uploaded once by the Host. data is the gzipped record,
# seat_holders is [{ seat, user_id }] (user_id null for a Seat nobody held) and is what decides who may
# read the record. The only game content 99staples stores.
class CreateGameRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :game_records do |t|
      t.references :room, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.binary :data, null: false
      t.string :end_status, null: false
      t.jsonb :seat_holders, null: false, default: []

      t.timestamps
    end
  end
end
