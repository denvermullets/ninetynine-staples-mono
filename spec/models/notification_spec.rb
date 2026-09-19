require 'rails_helper'

RSpec.describe Notification, type: :model do
  let(:user) { create(:user) }

  it 'refuses a kind it does not know' do
    expect(user.notifications.build(kind: 'nope')).not_to be_valid
  end

  it 'does not need a notifiable' do
    expect(user.notifications.build(kind: 'trade_proposed')).to be_valid
  end

  describe '.mark_all_read!' do
    it 'stamps only the unread ones' do
      earlier = 2.days.ago.change(usec: 0)
      read = user.notifications.create!(kind: 'trade_proposed', read_at: earlier)
      unread = user.notifications.create!(kind: 'trade_accepted')

      user.notifications.mark_all_read!

      expect(read.reload.read_at).to eq(earlier)
      expect(unread.reload).to be_read
    end
  end

  it 'goes when its notifiable does' do
    trade = create(:trade)
    trade.recipient.notifications.create!(kind: 'trade_proposed', notifiable: trade)

    expect { trade.destroy! }.to change(described_class, :count).by(-1)
  end
end
