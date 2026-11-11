# What an upload returns: the record's metadata, never its content.
class Api::V1::GameRecordSerializer
  def self.one(game_record)
    { room_id: game_record.room_id, end_status: game_record.end_status, seats: game_record.seat_holders,
      size: game_record.data.bytesize, created_at: game_record.created_at.utc.iso8601 }
  end
end
