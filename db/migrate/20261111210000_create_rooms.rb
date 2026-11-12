# A network game's Room: the Host opens it, others join with its Join code, and membership gates the Relay.
# status runs open -> started -> closed. The Join code only has to be unique while the Room is not closed,
# so a closed Room's code can be issued again but never admits anyone.
class CreateRooms < ActiveRecord::Migration[8.1]
  def change
    create_table :rooms do |t|
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.string :join_code, null: false
      t.string :status, null: false, default: 'open'
      t.datetime :started_at
      t.datetime :closed_at

      t.timestamps
    end

    add_index :rooms, :join_code, unique: true, where: "status <> 'closed'", name: 'index_rooms_on_live_join_code'

    create_table :room_memberships do |t|
      t.references :room, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :room_memberships, %i[room_id user_id], unique: true
  end
end
