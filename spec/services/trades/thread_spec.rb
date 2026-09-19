require 'rails_helper'

RSpec.describe Trades::Thread, type: :service do
  let(:alice) { create(:user, username: 'alice') }
  let(:bob) { create(:user, username: 'bob') }
  let(:original) { create(:trade, proposer: alice, recipient: bob, status: 'declined', message: 'Bolt for your Path?') }
  let(:counter) do
    create(:trade, proposer: bob, recipient: alice, parent_trade: original, message: 'Add a Swords and sure')
  end

  def steps(trade)
    described_class.call(trade: trade).map { |entry| [entry[:event].event, entry[:trade].id, entry[:message]] }
  end

  before do
    original.trade_events.create!(user: alice, event: 'proposed', created_at: 3.hours.ago)
    original.trade_events.create!(user: bob, event: 'countered', created_at: 2.hours.ago)
    counter.trade_events.create!(user: bob, event: 'proposed', created_at: 2.hours.ago)
    counter.trade_events.create!(user: alice, event: 'accepted', created_at: 1.hour.ago)
  end

  it 'reads the offer, then the counter and its answer, with each message on the step that sent it' do
    expected = [['proposed', original.id, 'Bolt for your Path?'],
                ['proposed', counter.id, 'Add a Swords and sure'],
                ['accepted', counter.id, nil]]

    expect(steps(counter)).to eq(expected)
    expect(steps(original)).to eq(expected)
  end

  it 'marks the steps that belong to the trade being looked at' do
    expect(described_class.call(trade: counter).map { |entry| entry[:current] }).to eq([false, true, true])
  end

  it 'follows a chain of counters in both directions' do
    counter.update!(status: 'declined')
    second = create(:trade, proposer: alice, recipient: bob, parent_trade: counter)
    second.trade_events.create!(user: alice, event: 'proposed')

    expect(steps(counter).map(&:second)).to eq([original.id, counter.id, counter.id, second.id])
  end

  it 'leaves trades outside the chain out' do
    create(:trade, proposer: alice, recipient: bob).trade_events.create!(user: alice, event: 'proposed')

    expect(steps(original).map(&:second).uniq).to eq([original.id, counter.id])
  end
end
