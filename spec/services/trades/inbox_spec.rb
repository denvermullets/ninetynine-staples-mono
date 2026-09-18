require 'rails_helper'

RSpec.describe Trades::Inbox, type: :service do
  let(:me) { create(:user, username: 'me') }
  let(:them) { create(:user, username: 'them') }

  let!(:incoming) { create(:trade, proposer: them, recipient: me) }
  let!(:incoming_accepted) { create(:trade, :accepted, proposer: them, recipient: me) }
  let!(:outgoing) { create(:trade, proposer: me, recipient: them) }
  let!(:closed) do
    %w[declined cancelled completed].map { |status| create(:trade, proposer: me, recipient: them, status: status) }
  end

  before { create(:trade) } # somebody else's trade entirely

  def inbox(tab)
    described_class.call(user: me, tab: tab)
  end

  it 'puts open trades proposed to the user in incoming, accepted ones included' do
    expect(inbox('incoming')[:trades]).to contain_exactly(incoming, incoming_accepted)
  end

  it 'puts open trades the user proposed in outgoing' do
    expect(inbox('outgoing')[:trades]).to contain_exactly(outgoing)
  end

  it 'puts every closed trade in history, whichever side the user was on' do
    received_and_declined = create(:trade, proposer: them, recipient: me, status: 'declined')

    expect(inbox('history')[:trades]).to contain_exactly(*closed, received_and_declined)
  end

  it 'counts every tab, not just the one showing' do
    expect(inbox('outgoing')[:counts]).to eq('incoming' => 2, 'outgoing' => 1, 'history' => 3)
  end

  it 'falls back to incoming for a tab it does not know' do
    expect(inbox('nonsense')[:tab]).to eq('incoming')
    expect(inbox(nil)[:tab]).to eq('incoming')
  end
end
