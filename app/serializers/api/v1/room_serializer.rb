# A Room as its members see it: the Join code to share, whether it still admits people, and who is in.
class Api::V1::RoomSerializer
  def self.one(room, viewer:)
    new(room, viewer: viewer).as_json
  end

  def initialize(room, viewer:)
    @room = room
    @viewer = viewer
  end

  def as_json(*)
    { id: @room.id, join_code: @room.join_code, status: @room.status, host_id: @room.host_id,
      host: @room.host?(@viewer), members: members }
  end

  private

  def members
    @room.members.order('room_memberships.id').map { |user| { id: user.id, username: user.username } }
  end
end
