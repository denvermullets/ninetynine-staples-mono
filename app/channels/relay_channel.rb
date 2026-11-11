# Relays opaque game payloads between a Room's Host and its Participants. Every member has their own
# stream: the Host addresses one Participant at a time, and a Participant can only reach the Host, with
# the sender's user id stamped here rather than trusted from the client. Payloads are never decoded and
# nothing is buffered for a member who isn't subscribed.
class RelayChannel < ApplicationCable::Channel
  def self.stream_for_member(room, user_id)
    "relay:room:#{room.id}:user:#{user_id}"
  end

  def subscribed
    @room = Room.live.find_by(id: params[:room_id])
    return reject unless @room&.member?(current_user)

    stream_from self.class.stream_for_member(@room, current_user.id)
  end

  # data: { 'payload' => String, 'to' => user id }. `to` is only read from the Host
  def relay(data)
    payload = data['payload']
    return unless payload.is_a?(String)

    recipient_id = @room.host?(current_user) ? recipient_for_host(data['to']) : @room.host_id
    return unless recipient_id

    ActionCable.server.broadcast(
      self.class.stream_for_member(@room, recipient_id),
      { 'from' => current_user.id, 'payload' => payload }
    )
  end

  private

  # the Host can only address another current member
  def recipient_for_host(to)
    id = Integer(to, exception: false)
    id if id && id != @room.host_id && @room.room_memberships.exists?(user_id: id)
  end
end
