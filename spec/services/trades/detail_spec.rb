require 'rails_helper'

RSpec.describe Trades::Detail, type: :service do
  let(:proposer) { create(:user, username: 'proposer') }
  let(:recipient) { create(:user, username: 'recipient') }
  let(:trade) { create(:trade, proposer: proposer, recipient: recipient) }

  def card(price)
    create(:magic_card, normal_price: price, foil_price: 0, ck_buylist_normal_price: 0, ck_buylist_foil_price: 0)
  end

  # snapshot at today's price unless a spec says otherwise, so nothing reads as drifted by accident
  def offer(side, magic_card, quantity: 1, **snapshots)
    create(:trade_item, trade: trade, magic_card: magic_card, side: side, quantity: quantity,
                        unit_price_snapshot: magic_card.normal_price, unit_foil_price_snapshot: 0,
                        unit_buylist_snapshot: 0, unit_buylist_foil_snapshot: 0, **snapshots)
  end

  def detail(viewer)
    described_class.call(trade: trade.reload, viewer: viewer)
  end

  before do
    offer('proposer', card(3), quantity: 2)
    offer('recipient', card(10))
  end

  it 'puts the viewer on the mine side and the counterparty on the theirs side' do
    result = detail(recipient)

    expect(result[:mine]).to include(name: 'recipient', user: recipient, retail: 10)
    expect(result[:theirs]).to include(name: 'proposer', user: proposer, retail: 6, copies: 2)
  end

  it 'reads the difference as what the viewer receives minus what they give' do
    expect(detail(proposer)[:difference]).to eq(4)
    expect(detail(recipient)[:difference]).to eq(-4)
  end

  it 'turns the live difference the same way' do
    trade.items_for('recipient').first.magic_card.update!(normal_price: 20)

    expect(detail(proposer)).to include(live_difference: 14, drift?: true)
    expect(detail(recipient)[:live_difference]).to eq(-14)
  end

  it 'offers only the steps the state machine allows the viewer' do
    expect(detail(proposer)[:actions]).to eq(%w[cancel])
    expect(detail(recipient)[:actions]).to eq(%w[accept decline cancel])
  end

  it 'carries each side\'s receipt confirmation' do
    trade.update!(status: 'accepted', recipient_completed_at: Time.current)

    expect(detail(proposer)[:theirs][:confirmed_at]).to be_present
    expect(detail(proposer)[:mine][:confirmed_at]).to be_nil
  end
end
