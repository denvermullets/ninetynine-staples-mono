# Relays opaque game payloads between a Room's Host and its Participants. Every member has their own
# stream: the Host addresses one Participant at a time, and a Participant can only reach the Host, with
# the sender's user id stamped here rather than trusted from the client. Payloads are never decoded and
# nothing is buffered for a member who isn't subscribed. Presence (joined, left, dropped) is the only
# thing every member hears, and a member has one subscription per Room: the newest one wins.
class RelayChannel < ApplicationCable::Channel
  # Largest payload (bytes) accepted from one message. A Frame is the full compressed snapshot of one
  # viewer's game, expected to be tens of KB (0.3-3 KB for ordinary messages), so 256 KB leaves ~10x
  # headroom while keeping a single message far below what could stall the shared Cable. Rack::Attack
  # never sees socket frames, so this is enforced here. Override with RELAY_MAX_MESSAGE_BYTES.
  DEFAULT_MAX_MESSAGE_BYTES = 256 * 1024

  def self.max_message_bytes
    Integer(ENV.fetch('RELAY_MAX_MESSAGE_BYTES', DEFAULT_MAX_MESSAGE_BYTES), exception: false) ||
      DEFAULT_MAX_MESSAGE_BYTES
  end

  # Non-Host senders get a token bucket per subscription: commands, payment edits and settings run at
  # about one message a second with bursts, so the bucket holds DEFAULT_RATE_BURST messages and refills
  # at DEFAULT_RATE_PER_SECOND. The Host is exempt. Override with RELAY_RATE_PER_SECOND and
  # RELAY_RATE_BURST.
  DEFAULT_RATE_PER_SECOND = 2.0
  DEFAULT_RATE_BURST = 20

  def self.rate_per_second
    value = Float(ENV.fetch('RELAY_RATE_PER_SECOND', DEFAULT_RATE_PER_SECOND), exception: false)
    value&.positive? ? value : DEFAULT_RATE_PER_SECOND
  end

  def self.rate_burst
    value = Integer(ENV.fetch('RELAY_RATE_BURST', DEFAULT_RATE_BURST), exception: false)
    value&.positive? ? value : DEFAULT_RATE_BURST
  end

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
    return reject_rate_limited if throttled?
    return reject_oversized if payload.bytesize > self.class.max_message_bytes

    recipient_id = @room.host?(current_user) ? recipient_for_host(data['to']) : @room.host_id
    return unless recipient_id

    ActionCable.server.broadcast(
      self.class.stream_for_member(@room, recipient_id),
      { 'from' => current_user.id, 'payload' => payload }
    )
  end

  private

  def reject_rate_limited
    transmit({ 'type' => 'error', 'error' => 'rate_limited', 'limit' => self.class.rate_per_second })
  end

  # refills the bucket for the time since the last message, then spends one token if there is one
  def throttled?
    return false if @room.host?(current_user)

    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    burst = self.class.rate_burst
    @tokens = [burst, (@tokens || burst) + ((now - (@token_time || now)) * self.class.rate_per_second)].min
    @token_time = now
    return true if @tokens < 1

    @tokens -= 1
    false
  end

  def reject_oversized
    transmit({ 'type' => 'error', 'error' => 'message_too_large', 'limit' => self.class.max_message_bytes })
  end

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
