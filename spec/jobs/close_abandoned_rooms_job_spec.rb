require 'rails_helper'

RSpec.describe CloseAbandonedRoomsJob, type: :job do
  it 'closes Rooms the Host has been absent from for 24 hours' do
    room = Room.open_for!(create(:user))
    room.update!(host_present: false, host_last_seen_at: 25.hours.ago)

    described_class.perform_now

    expect(room.reload).to be_closed
  end
end
