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
end
