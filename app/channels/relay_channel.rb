# Relays opaque game payloads between a Room's Host and its Participants. Every member has their own
# stream: the Host addresses one Participant at a time, and a Participant can only reach the Host, with
# the sender's user id stamped here rather than trusted from the client. Payloads are never decoded and
# nothing is buffered for a member who isn't subscribed. Presence (joined, left, dropped) is the only
# thing every member hears, and a member has one subscription per Room: the newest one wins.
class RelayChannel < ApplicationCable::Channel
  def self.stream_for_member(room, user_id)
    "relay:room:#{room.id}:user:#{user_id}"
  end

  def self.presence_stream(room)
    "relay:room:#{room.id}:presence"
  end

  # carries only which subscription is the newest, so an older one can drop itself even when it lives
  # in another process
  def self.control_stream(room, user_id)
    "relay:room:#{room.id}:user:#{user_id}:control"
  end

  def subscribed
    @room = Room.live.find_by(id: params[:room_id])
    return reject unless @room&.member?(current_user)

    become_newest
    stream_from self.class.stream_for_member(@room, current_user.id)
    stream_from self.class.presence_stream(@room)
    broadcast_presence('joined')
  end

  def unsubscribed
    return if @superseded || @subscription_id.nil?

    broadcast_presence(connection.try(:closing?) ? 'dropped' : 'left')
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

  def become_newest
    control = self.class.control_stream(@room, current_user.id)
    @subscription_id = SecureRandom.uuid
    stream_from control, ->(message) { handle_control(message) }
    ActionCable.server.broadcast(control, { 'type' => 'newest', 'subscription' => @subscription_id })
  end

  def handle_control(message)
    return if message['type'] != 'newest' || message['subscription'] == @subscription_id

    @superseded = true
    unsubscribe_from_channel
  end

  def broadcast_presence(event)
    ActionCable.server.broadcast(
      self.class.presence_stream(@room), { 'type' => 'presence', 'event' => event, 'user_id' => current_user.id }
    )
  end

  # the Host can only address another current member
  def recipient_for_host(to)
    id = Integer(to, exception: false)
    id if id && id != @room.host_id && @room.room_memberships.exists?(user_id: id)
  end
end
