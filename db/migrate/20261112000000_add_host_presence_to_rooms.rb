# Whether the Host is subscribed to the Relay and when they were last there. A Room with no Host for 24 hours
# is closed by CloseAbandonedRoomsJob. Existing Rooms count as seen when the migration runs.
class AddHostPresenceToRooms < ActiveRecord::Migration[8.1]
  def change
    add_column :rooms, :host_present, :boolean, null: false, default: false
    add_column :rooms, :host_last_seen_at, :datetime
    reversible { |dir| dir.up { execute('UPDATE rooms SET host_last_seen_at = NOW()') } }
  end
end
