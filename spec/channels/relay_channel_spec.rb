require 'rails_helper'

RSpec.describe RelayChannel, type: :channel do
  let(:host) { create(:user) }
  let(:alice) { create(:user) }
  let(:bob) { create(:user) }
  let(:room) { Room.open_for!(host) }

  before do
    room.room_memberships.create!(user: alice)
    room.room_memberships.create!(user: bob)
  end

  def stream_for(user) = described_class.stream_for_member(room, user.id)

  def relay_as(user, data)
    stub_connection current_user: user
    subscribe room_id: room.id
    perform :relay, data
  end

  describe 'subscribing' do
    it 'accepts a member on their own stream' do
      stub_connection current_user: alice
      subscribe room_id: room.id

      expect(subscription).to be_confirmed
      expect(subscription).to have_stream_from(stream_for(alice))
      expect(subscription).not_to have_stream_from(stream_for(bob))
    end

    it 'accepts the Host' do
      stub_connection current_user: host
      subscribe room_id: room.id

      expect(subscription).to have_stream_from(stream_for(host))
    end

    it 'rejects a non-member' do
      stub_connection current_user: create(:user)
      subscribe room_id: room.id

      expect(subscription).to be_rejected
    end

    it 'rejects a Removed member' do
      room.remove_member!(alice)
      stub_connection current_user: alice
      subscribe room_id: room.id

      expect(subscription).to be_rejected
    end

    it 'drops a live subscription when its member is Removed' do
      stub_connection current_user: alice
      subscribe room_id: room.id

      expect { subscription.send(:handle_control, 'type' => 'removed') }
        .not_to have_broadcasted_to(described_class.presence_stream(room))
      expect(subscription).not_to have_streams
    end

    it 'rejects an unknown Room' do
      stub_connection current_user: alice
      subscribe room_id: 0

      expect(subscription).to be_rejected
    end

    it 'rejects a closed Room' do
      room.close!
      stub_connection current_user: alice
      subscribe room_id: room.id

      expect(subscription).to be_rejected
    end
  end

  describe 'Host presence' do
    it 'lets a member subscribe while the Host is absent' do
      room.update!(host_present: false, host_last_seen_at: 23.hours.ago)
      stub_connection current_user: alice
      subscribe room_id: room.id

      expect(subscription).to be_confirmed
    end

    it 'marks the Host present while they are subscribed and absent once they leave' do
      room.update!(host_present: false, host_last_seen_at: 2.hours.ago)
      stub_connection current_user: host
      subscribe room_id: room.id

      expect(room.reload).to be_host_present

      unsubscribe

      expect(room.reload).not_to be_host_present
      expect(room.host_last_seen_at).to be_within(5.seconds).of(Time.current)
    end

    it 'refreshes the Host last seen time when the Host relays, at most about once a minute' do
      stub_connection current_user: host
      subscribe room_id: room.id
      room.update_columns(host_last_seen_at: 2.minutes.ago)

      perform :relay, 'payload' => 'a', 'to' => alice.id
      refreshed = room.reload.host_last_seen_at
      expect(refreshed).to be_within(5.seconds).of(Time.current)

      room.update_columns(host_last_seen_at: 10.seconds.ago)
      stale = room.reload.host_last_seen_at
      perform :relay, 'payload' => 'b', 'to' => alice.id

      expect(room.reload.host_last_seen_at).to eq(stale)
    end

    it 'does not refresh the Room when a Participant relays' do
      room.update_columns(host_last_seen_at: 2.hours.ago)
      relay_as(alice, 'payload' => 'x')

      expect(room.reload.host_last_seen_at).to be < 1.hour.ago
    end

    it 'does not mark the Room when a Participant comes and goes' do
      room.update!(host_present: false, host_last_seen_at: 2.hours.ago)
      stub_connection current_user: alice
      subscribe room_id: room.id
      unsubscribe

      expect(room.reload.host_last_seen_at).to be < 1.hour.ago
    end

    it 'keeps the Host present when an older Host subscription is superseded' do
      stub_connection current_user: host
      subscribe room_id: room.id
      subscription.send(:handle_control, 'type' => 'newest', 'subscription' => 'someone-else')

      expect(room.reload).to be_host_present
    end
  end

  describe 'Room closing' do
    it 'drops a live subscription and tells the member the Room closed' do
      stub_connection current_user: alice
      subscribe room_id: room.id

      expect { subscription.send(:handle_control, 'type' => 'closed') }
        .not_to have_broadcasted_to(described_class.presence_stream(room))
      expect(subscription).not_to have_streams
      expect(transmissions.last).to eq('type' => 'closed')
    end

    it 'tells every member to drop when the Room closes' do
      expect { room.close! }
        .to have_broadcasted_to(described_class.control_stream(room, alice.id)).with('type' => 'closed')
        .and have_broadcasted_to(described_class.control_stream(room, host.id)).with('type' => 'closed')
    end
  end

  describe 'presence' do
    def presence(event, user) = { 'type' => 'presence', 'event' => event, 'user_id' => user.id }

    def subscribe_as(user)
      stub_connection current_user: user
      subscribe room_id: room.id
    end

    it 'puts every member on the Room presence stream' do
      subscribe_as(alice)

      expect(subscription).to have_stream_from(described_class.presence_stream(room))
    end

    it 'broadcasts joined to the Room when a member subscribes' do
      expect { subscribe_as(alice) }
        .to have_broadcasted_to(described_class.presence_stream(room)).with(presence('joined', alice))
    end

    it 'broadcasts nothing when a subscription is rejected' do
      expect { subscribe_as(create(:user)) }
        .not_to have_broadcasted_to(described_class.presence_stream(room))
    end

    it 'broadcasts left when a member unsubscribes' do
      subscribe_as(alice)

      expect { unsubscribe }
        .to have_broadcasted_to(described_class.presence_stream(room)).with(presence('left', alice))
    end

    it 'broadcasts dropped when the socket closes' do
      subscribe_as(alice)
      connection.define_singleton_method(:closing?) { true }

      expect { unsubscribe }
        .to have_broadcasted_to(described_class.presence_stream(room)).with(presence('dropped', alice))
    end
  end

  describe 'newest connection wins' do
    it 'tells older subscriptions of the user to drop on a new subscribe' do
      expect { subscribe_as_alice }
        .to have_broadcasted_to(described_class.control_stream(room, alice.id))
        .with(hash_including('type' => 'newest', 'subscription' => be_a(String)))
    end

    it 'drops a subscription when another becomes the newest' do
      subscribe_as_alice
      first = subscription

      first.send(:handle_control, 'type' => 'newest', 'subscription' => 'someone-else')

      expect(first).not_to have_streams
    end

    it 'keeps the subscription that is the newest' do
      subscribe_as_alice
      id = subscription.instance_variable_get(:@subscription_id)

      subscription.send(:handle_control, 'type' => 'newest', 'subscription' => id)

      expect(subscription.streams).not_to be_empty
    end

    it 'does not announce a superseded subscription as having left' do
      subscribe_as_alice

      expect { subscription.send(:handle_control, 'type' => 'newest', 'subscription' => 'x') }
        .not_to have_broadcasted_to(described_class.presence_stream(room))
    end

    def subscribe_as_alice
      stub_connection current_user: alice
      subscribe room_id: room.id
    end
  end

  describe 'Host to Participant' do
    it 'reaches only the addressed Participant' do
      expect { relay_as(host, 'to' => alice.id, 'payload' => 'frame') }
        .to have_broadcasted_to(stream_for(alice)).with('from' => host.id, 'payload' => 'frame')
    end

    it 'does not reach another Participant' do
      expect { relay_as(host, 'to' => alice.id, 'payload' => 'frame') }
        .not_to have_broadcasted_to(stream_for(bob))
    end

    it 'sends nothing without a valid recipient' do
      expect { relay_as(host, 'payload' => 'frame') }.not_to have_broadcasted_to(stream_for(alice))
    end

    it 'sends nothing to a non-member' do
      outsider = create(:user)

      expect { relay_as(host, 'to' => outsider.id, 'payload' => 'frame') }
        .not_to have_broadcasted_to(stream_for(outsider))
    end

    it 'does not relay to itself' do
      expect { relay_as(host, 'to' => host.id, 'payload' => 'frame') }.not_to have_broadcasted_to(stream_for(host))
    end
  end

  describe 'Participant to Host' do
    it 'reaches the Host with the Relay-stamped sender' do
      expect { relay_as(alice, 'payload' => 'cmd') }
        .to have_broadcasted_to(stream_for(host)).with('from' => alice.id, 'payload' => 'cmd')
    end

    it 'overwrites a client-supplied sender' do
      expect { relay_as(alice, 'payload' => 'cmd', 'from' => bob.id, 'sender' => bob.id) }
        .to have_broadcasted_to(stream_for(host)).with('from' => alice.id, 'payload' => 'cmd')
    end

    it 'cannot address another Participant' do
      expect { relay_as(alice, 'to' => bob.id, 'payload' => 'cmd') }
        .not_to have_broadcasted_to(stream_for(bob))
    end

    it 'still goes to the Host when it names another Participant' do
      expect { relay_as(alice, 'to' => bob.id, 'payload' => 'cmd') }
        .to have_broadcasted_to(stream_for(host)).with('from' => alice.id, 'payload' => 'cmd')
    end
  end

  it 'ignores a payload that is not a string' do
    expect { relay_as(alice, 'payload' => { 'a' => 1 }) }.not_to have_broadcasted_to(stream_for(host))
  end

  describe 'message size cap' do
    around do |example|
      old = ENV.fetch('RELAY_MAX_MESSAGE_BYTES', nil)
      ENV['RELAY_MAX_MESSAGE_BYTES'] = '10'
      example.run
    ensure
      old ? ENV['RELAY_MAX_MESSAGE_BYTES'] = old : ENV.delete('RELAY_MAX_MESSAGE_BYTES')
    end

    it 'drops an over-cap message, forwards nothing and tells the sender' do
      expect { relay_as(alice, 'payload' => 'x' * 11) }
        .not_to have_broadcasted_to(stream_for(host))
      expect(transmissions.last).to eq('type' => 'error', 'error' => 'message_too_large', 'limit' => 10)
    end

    it 'applies to the Host too' do
      expect { relay_as(host, 'payload' => 'x' * 11, 'to' => alice.id) }
        .not_to have_broadcasted_to(stream_for(alice))
      expect(transmissions.last['error']).to eq('message_too_large')
    end

    it 'forwards a message exactly at the cap' do
      expect { relay_as(alice, 'payload' => 'x' * 10) }
        .to have_broadcasted_to(stream_for(host)).with('from' => alice.id, 'payload' => 'x' * 10)
    end

    it 'counts bytes, not characters' do
      expect { relay_as(alice, 'payload' => "\u00e9" * 6) }.not_to have_broadcasted_to(stream_for(host))
    end
  end

  describe 'rate cap' do
    around do |example|
      keep = %w[RELAY_RATE_PER_SECOND RELAY_RATE_BURST].to_h { |k| [k, ENV.fetch(k, nil)] }
      ENV['RELAY_RATE_PER_SECOND'] = '1'
      ENV['RELAY_RATE_BURST'] = '3'
      example.run
    ensure
      keep.each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
    end

    let(:clock) { [100.0] }

    before do
      allow(Process).to receive(:clock_gettime).and_call_original
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { clock.first }
    end

    def flood(user, count)
      stub_connection current_user: user
      subscribe room_id: room.id
      count.times { perform :relay, 'payload' => 'cmd', 'to' => alice.id }
    end

    it 'lets a burst up to the cap through' do
      expect { flood(alice, 3) }.to have_broadcasted_to(stream_for(host)).exactly(3).times
      expect(transmissions.grep(Hash).map { |t| t['error'] }).not_to include('rate_limited')
    end

    it 'throttles a flood and tells the sender' do
      expect { flood(alice, 5) }.to have_broadcasted_to(stream_for(host)).exactly(3).times
      expect(transmissions.last).to eq('type' => 'error', 'error' => 'rate_limited', 'limit' => 1.0)
    end

    it 'refills over time' do
      flood(alice, 5)
      clock[0] += 2
      expect { perform :relay, 'payload' => 'cmd' }.to have_broadcasted_to(stream_for(host)).exactly(1).times
      expect { perform :relay, 'payload' => 'cmd' }.to have_broadcasted_to(stream_for(host)).exactly(1).times
      expect { perform :relay, 'payload' => 'cmd' }.not_to have_broadcasted_to(stream_for(host))
    end

    it 'never throttles the Host' do
      expect { flood(host, 10) }.to have_broadcasted_to(stream_for(alice)).exactly(10).times
    end

    it 'throttles each Participant separately' do
      flood(alice, 5)
      expect { relay_as(bob, 'payload' => 'cmd') }.to have_broadcasted_to(stream_for(host))
    end
  end

  describe 'default cap' do
    it 'is 256 KB' do
      expect(described_class.max_message_bytes).to eq(262_144)
    end
  end
end
