require 'rails_helper'

RSpec.describe Trades::Propose, type: :service do
  let(:proposer) { create(:user, username: 'proposer', trades_public: true) }
  let(:recipient) { create(:user, username: 'recipient', trades_public: true) }
  let(:card) { create(:magic_card, name: 'Sol Ring', normal_price: 3, foil_price: 9) }

  def binder_row(user, quantity: 4, foil_quantity: 0, **opts)
    collection = create(:collection, user: user, is_public: opts.fetch(:public, true))
    create(:collection_magic_card, collection: collection, magic_card: card,
                                   quantity: quantity, foil_quantity: foil_quantity,
                                   trade_quantity: opts[:trade_quantity] || quantity,
                                   trade_foil_quantity: opts[:trade_foil_quantity] || foil_quantity)
  end

  def propose(items, from: proposer, to: recipient)
    described_class.call(proposer: from, recipient: to, items: items)
  end

  def item(row, side, quantity: 1, foil_quantity: 0)
    { collection_magic_card_id: row.id, side: side, quantity: quantity, foil_quantity: foil_quantity }
  end

  describe 'a valid proposal' do
    let(:mine) { binder_row(proposer) }
    let(:theirs) { binder_row(recipient) }

    it 'creates a proposed trade with a card on each side' do
      result = propose([item(mine, 'proposer', quantity: 2), item(theirs, 'recipient')])

      expect(result[:success]).to be(true)
      trade = result[:trade]
      expect(trade).to be_proposed
      expect(trade.items_for('proposer').sum(&:quantity)).to eq(2)
      expect(trade.items_for('recipient').sum(&:quantity)).to eq(1)
    end

    it 'snapshots the prices the card carried at proposal time' do
      trade = propose([item(mine, 'proposer')])[:trade]
      card.update!(normal_price: 99, foil_price: 199)

      offered = trade.trade_items.first
      expect(offered.unit_price_snapshot).to eq(3)
      expect(offered.unit_foil_price_snapshot).to eq(9)
    end

    it 'starts the timeline with the proposal' do
      trade = propose([item(mine, 'proposer')])[:trade]

      expect(trade.trade_events.map { |event| [event.event, event.user] }).to eq([['proposed', proposer]])
    end

    it 'leaves the collection counts alone - a proposal moves nothing' do
      propose([item(mine, 'proposer', quantity: 2)])
      expect(mine.reload).to have_attributes(quantity: 4, trade_quantity: 4)
    end

    it 'notifies the recipient' do
      trade = propose([item(mine, 'proposer')])[:trade]

      expect(recipient.notifications.map { |n| [n.kind, n.notifiable] }).to eq([['trade_proposed', trade]])
      expect(proposer.notifications).to be_empty
    end
  end

  describe 'guards' do
    it 'refuses a proposal to a user with a private trade list' do
      recipient.update!(trades_public: false)
      result = propose([item(binder_row(proposer), 'proposer')])

      expect(result).to include(success: false)
      expect(result[:error]).to match(/not accepting trade offers/)
    end

    it 'refuses a trade with yourself' do
      expect(propose([], to: proposer)).to include(success: false)
    end

    it 'refuses a trade with no cards on it' do
      expect(propose([])[:error]).to match(/at least one card/)
    end

    it 'refuses an item on a side its owner is not on' do
      mine = binder_row(proposer)
      expect(propose([item(mine, 'recipient')])[:error]).to match(/not offering that card/)
    end

    it 'refuses a card the owner has not marked for trade' do
      row = binder_row(proposer, trade_quantity: 0)
      expect(propose([item(row, 'proposer')])[:error]).to match(/not offering that card/)
    end

    it 'refuses a card sitting in a private collection' do
      row = binder_row(proposer, public: false)
      expect(propose([item(row, 'proposer')])[:error]).to match(/not offering that card/)
    end

    it 'refuses more copies than are marked for trade' do
      row = binder_row(proposer, quantity: 4, trade_quantity: 1)
      expect(propose([item(row, 'proposer', quantity: 2)])[:error]).to match(/Only 1 copy/)
    end

    it 'writes nothing when one item of many is bad' do
      good = binder_row(proposer)
      bad = binder_row(proposer, trade_quantity: 0)

      expect { propose([item(good, 'proposer'), item(bad, 'proposer')]) }.not_to change(Trade, :count)
    end
  end

  describe 'the double-booking guard' do
    let(:other_user) { create(:user, username: 'third', trades_public: true) }

    it 'counts copies already committed to another open trade against the offer' do
      row = binder_row(proposer, quantity: 4, trade_quantity: 4)
      propose([item(row, 'proposer', quantity: 3)], to: other_user)

      expect(propose([item(row, 'proposer', quantity: 2)])[:error]).to match(/Only 1 copy/)
    end

    it 'allows the copies that are left over' do
      row = binder_row(proposer, quantity: 4, trade_quantity: 4)
      propose([item(row, 'proposer', quantity: 3)], to: other_user)

      expect(propose([item(row, 'proposer')])).to include(success: true)
    end

    it 'frees the copies again once the first trade is declined' do
      row = binder_row(proposer, quantity: 4, trade_quantity: 4)
      first = propose([item(row, 'proposer', quantity: 4)], to: other_user)[:trade]
      Trades::Transition.call(trade: first, user: other_user, event: 'decline')

      expect(propose([item(row, 'proposer', quantity: 4)])).to include(success: true)
    end

    it 'still counts copies committed to an accepted trade' do
      row = binder_row(proposer, quantity: 4, trade_quantity: 4)
      first = propose([item(row, 'proposer', quantity: 4)], to: other_user)[:trade]
      Trades::Transition.call(trade: first, user: other_user, event: 'accept')

      expect(propose([item(row, 'proposer')])[:error]).to match(/Only 0 copies/)
    end

    it 'tracks foils separately from regular copies' do
      row = binder_row(proposer, quantity: 2, foil_quantity: 2)
      propose([item(row, 'proposer', quantity: 0, foil_quantity: 2)], to: other_user)

      expect(propose([item(row, 'proposer', quantity: 2)])).to include(success: true)
      expect(propose([item(row, 'proposer', quantity: 0, foil_quantity: 1)])[:error]).to match(/foil copies/)
    end

    it 'books a row against its owner whichever end of the trade they are on' do
      theirs = binder_row(recipient, quantity: 2, trade_quantity: 2)
      # the proposer asks for both copies, so they are committed on the recipient's side
      propose([item(theirs, 'recipient', quantity: 2)])

      expect(propose([item(theirs, 'recipient')], from: other_user)[:error]).to match(/Only 0 copies/)
    end
  end
end
