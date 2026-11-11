# Who the Host Removed from a Room. A Removed user is out of the Room's memberships and this row bars them
# from joining or subscribing to it again, even with the Join code.
class CreateRoomRemovals < ActiveRecord::Migration[8.1]
  def change
    create_table :room_removals do |t|
      t.references :room, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :room_removals, %i[room_id user_id], unique: true
  end
end
