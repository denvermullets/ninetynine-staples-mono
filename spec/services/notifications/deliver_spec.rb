require 'rails_helper'

RSpec.describe Notifications::Deliver, type: :service do
  let(:trade) { create(:trade) }
  let(:user) { trade.recipient }
  let(:stream) { "user_#{user.id}_notifications" }

  def deliver
    described_class.call(user: user, kind: 'trade_proposed', notifiable: trade)
  end

  it 'records an unread notification' do
    notification = deliver

    expect(notification).to be_persisted
    expect(notification).to have_attributes(user: user, kind: 'trade_proposed', notifiable: trade, read_at: nil)
  end

  it 'toasts and refreshes the unread badges on the user stream' do
    expect { deliver }.to have_broadcasted_to(stream).exactly(3).times
  end

  it 'says what happened in the toast' do
    expect { deliver }.to have_broadcasted_to(stream).with(a_string_including('proposed a trade to you'))
  end

  it 'skips the per-type badge when there is no notifiable' do
    expect { described_class.call(user: user, kind: 'trade_proposed') }
      .to have_broadcasted_to(stream).exactly(2).times
  end

  it 'broadcasts nothing, and keeps nothing, when the surrounding transaction rolls back' do
    expect do
      ActiveRecord::Base.transaction do
        deliver
        raise ActiveRecord::Rollback
      end
    end.not_to have_broadcasted_to(stream)

    expect(Notification.count).to eq(0)
  end
end
