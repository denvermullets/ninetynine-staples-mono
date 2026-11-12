require 'rails_helper'

RSpec.describe Room do
  describe '.close_abandoned!' do
    let(:host) { create(:user) }

    def room_unseen_for(duration, present: false)
      room = described_class.open_for!(create(:user))
      room.update!(host_present: present, host_last_seen_at: duration.ago)
      room
    end

    it 'closes a Room whose Host has been gone over 24 hours' do
      room = room_unseen_for(25.hours)

      described_class.close_abandoned!

      expect(room.reload).to be_closed
      expect(room.closed_at).to be_present
    end

    it 'closes a Room whose Host is marked present but has been silent over 24 hours' do
      room = room_unseen_for(25.hours, present: true)

      described_class.close_abandoned!

      expect(room.reload).to be_closed
    end

    it 'closes a started Room too' do
      room = room_unseen_for(25.hours)
      room.update!(status: 'started')

      described_class.close_abandoned!

      expect(room.reload).to be_closed
    end

    it 'leaves a Room whose Host left under 24 hours ago' do
      room = room_unseen_for(23.hours)

      described_class.close_abandoned!

      expect(room.reload).to be_open
    end

    it 'leaves a Room whose Host marked present was active under 24 hours ago' do
      room = room_unseen_for(23.hours, present: true)

      described_class.close_abandoned!

      expect(room.reload).to be_open
    end

    it 'leaves already closed Rooms alone' do
      room = room_unseen_for(30.hours)
      room.close!
      closed_at = room.reload.closed_at

      described_class.close_abandoned!

      expect(room.reload.closed_at).to eq(closed_at)
    end

    it 'treats a new Room as seen when it was opened' do
      room = described_class.open_for!(host)

      expect(room.host_last_seen_at).to be_within(5.seconds).of(Time.current)
    end
  end
end
