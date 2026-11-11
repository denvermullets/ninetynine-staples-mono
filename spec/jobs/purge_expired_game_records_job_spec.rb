require 'rails_helper'

RSpec.describe PurgeExpiredGameRecordsJob, type: :job do
  def record_for(host, created_at:)
    room = Room.open_for!(host).tap(&:start!)
    GameRecord.create!(room: room, end_status: 'finished', data: GameRecord.compress('{}'), created_at: created_at,
                       seat_holders: [{ 'seat' => 0, 'user_id' => host.id }])
  end

  it 'deletes records older than 30 days and keeps newer ones' do
    host = create(:user)
    old = record_for(host, created_at: 31.days.ago)
    fresh = record_for(host, created_at: 29.days.ago)

    described_class.perform_now

    expect(GameRecord.exists?(old.id)).to be(false)
    expect(GameRecord.exists?(fresh.id)).to be(true)
  end
end
