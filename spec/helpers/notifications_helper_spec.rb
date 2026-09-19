require 'rails_helper'

RSpec.describe NotificationsHelper, type: :helper do
  let(:trade) { create(:trade) }

  it 'has a sentence for every kind' do
    expect(described_class::TEXT.keys).to match_array(Notification::KINDS)
  end

  it 'names the other party of a trade as the actor' do
    notification = trade.proposer.notifications.create!(kind: 'trade_accepted', notifiable: trade)

    expect(helper.notification_text(notification)).to eq("#{trade.recipient.username} accepted your trade.")
  end

  it 'sends a trade notification to its trade' do
    notification = trade.recipient.notifications.create!(kind: 'trade_proposed', notifiable: trade)

    expect(helper.notification_target_path(notification)).to eq(trade_path(trade))
  end
end
