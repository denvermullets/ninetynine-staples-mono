require 'rails_helper'

RSpec.describe Trades::Transition, type: :service do
  let(:proposer) { create(:user, username: 'proposer', trades_public: true) }
  let(:recipient) { create(:user, username: 'recipient', trades_public: true) }
  let(:outsider) { create(:user, username: 'outsider') }
  let(:trade) { create(:trade, proposer: proposer, recipient: recipient) }

  def transition(event, user:, on: trade)
    described_class.call(trade: on, user: user, event: event)
  end

  describe 'proposed -> accepted' do
    it 'lets the recipient accept' do
      expect(transition('accept', user: recipient)).to include(success: true)
      expect(trade.reload).to be_accepted
    end

    it 'does not let the proposer accept their own offer' do
      expect(transition('accept', user: proposer)[:error]).to match(/Only the recipient/)
      expect(trade.reload).to be_proposed
    end

    it 'does not let an outsider touch it' do
      expect(transition('accept', user: outsider)[:error]).to match(/not your trade/)
    end

    it 'cannot re-accept an accepted trade' do
      transition('accept', user: recipient)
      expect(transition('accept', user: recipient)[:error]).to match(/already accepted/)
    end
  end

  describe 'proposed -> declined' do
    it 'lets the recipient decline' do
      expect(transition('decline', user: recipient)).to include(success: true)
      expect(trade.reload).to be_declined
    end

    it 'does not let the proposer decline' do
      expect(transition('decline', user: proposer)[:error]).to match(/Only the recipient/)
    end

    it 'cannot decline an accepted trade' do
      transition('accept', user: recipient)
      expect(transition('decline', user: recipient)[:error]).to match(/already accepted/)
    end
  end

  describe 'cancelling' do
    %i[proposer recipient].each do |party|
      it "lets the #{party} cancel a proposed trade" do
        expect(transition('cancel', user: send(party))).to include(success: true)
        expect(trade.reload).to be_cancelled
      end

      it "lets the #{party} cancel an accepted trade" do
        transition('accept', user: recipient)
        expect(transition('cancel', user: send(party))).to include(success: true)
      end
    end

    it 'does not let an outsider cancel' do
      expect(transition('cancel', user: outsider)[:error]).to match(/not your trade/)
    end

    %w[declined cancelled completed].each do |status|
      it "cannot cancel a #{status} trade" do
        closed = create(:trade, proposer: proposer, recipient: recipient, status: status)
        expect(transition('cancel', user: proposer, on: closed)[:error]).to match(/no longer be cancelled/)
      end
    end
  end

  describe 'completing' do
    let(:card) { create(:magic_card, name: 'Sol Ring') }
    let(:row) do
      create(:collection_magic_card, collection: create(:collection, user: proposer), magic_card: card,
                                     quantity: 3, foil_quantity: 1, trade_quantity: 2, trade_foil_quantity: 1)
    end
    let(:trade) { create(:trade, :accepted, proposer: proposer, recipient: recipient) }

    before do
      create(:trade_item, trade: trade, collection_magic_card: row, magic_card: card,
                          side: 'proposer', quantity: 2, foil_quantity: 1)
    end

    it 'stays accepted until both parties confirm' do
      expect(transition('complete', user: proposer)).to include(success: true)
      expect(trade.reload).to be_accepted
      expect(trade.proposer_completed_at).to be_present
      expect(trade.recipient_completed_at).to be_nil
    end

    it 'completes once the second party confirms' do
      transition('complete', user: proposer)
      transition('complete', user: recipient)

      expect(trade.reload).to be_completed
    end

    it 'refuses a second confirmation from the same party' do
      transition('complete', user: proposer)
      expect(transition('complete', user: proposer)[:error]).to match(/already confirmed/)
    end

    it 'cannot complete a trade that was never accepted' do
      open_trade = create(:trade, proposer: proposer, recipient: recipient)
      expect(transition('complete', user: proposer, on: open_trade)[:error]).to match(/Only an accepted trade/)
    end

    it 'takes the traded copies off offer without touching what is owned' do
      transition('complete', user: proposer)
      transition('complete', user: recipient)

      expect(row.reload).to have_attributes(
        quantity: 3, foil_quantity: 1, trade_quantity: 0, trade_foil_quantity: 0
      )
    end

    it 'leaves the copies on offer while only one party has confirmed' do
      transition('complete', user: proposer)
      expect(row.reload).to have_attributes(trade_quantity: 2, trade_foil_quantity: 1)
    end

    it 'clamps at zero when the owner already lowered the count' do
      row.update!(trade_quantity: 1, trade_foil_quantity: 0)
      transition('complete', user: proposer)
      transition('complete', user: recipient)

      expect(row.reload).to have_attributes(trade_quantity: 0, trade_foil_quantity: 0)
    end

    it 'takes nothing off a row the trade reached past the trade list for' do
      row.update!(trade_quantity: 0, trade_foil_quantity: 0)
      transition('complete', user: proposer)
      transition('complete', user: recipient)

      expect(row.reload).to have_attributes(quantity: 3, foil_quantity: 1, trade_quantity: 0, trade_foil_quantity: 0)
    end

    it 'completes even after the binder row was deleted' do
      row.destroy
      transition('complete', user: proposer)

      expect(transition('complete', user: recipient)).to include(success: true)
      expect(trade.reload).to be_completed
    end
  end

  describe 'the timeline' do
    def timeline
      trade.reload.trade_events.map { |event| [event.event, event.user&.username] }
    end

    it 'records each step with who took it' do
      transition('accept', user: recipient)
      transition('cancel', user: proposer)

      expect(timeline).to eq([%w[accepted recipient], %w[cancelled proposer]])
    end

    it 'records each confirmation, then the trade completing on its own' do
      transition('accept', user: recipient)
      transition('complete', user: recipient)
      transition('complete', user: proposer)

      expect(timeline).to eq([%w[accepted recipient], %w[confirmed recipient], %w[confirmed proposer],
                              ['completed', nil]])
    end

    it 'records nothing for a refused step' do
      transition('accept', user: proposer)

      expect(timeline).to be_empty
    end
  end

  describe 'notifications' do
    def notified(user)
      user.notifications.where(notifiable: trade).pluck(:kind)
    end

    %w[accept decline].each do |event|
      it "tells the proposer when the recipient #{event}s" do
        transition(event, user: recipient)

        expect(notified(proposer)).to eq(["trade_#{trade.reload.status}"])
        expect(notified(recipient)).to be_empty
      end
    end

    it 'tells whoever did not cancel' do
      transition('cancel', user: proposer)

      expect(notified(recipient)).to eq(%w[trade_cancelled])
      expect(notified(proposer)).to be_empty
    end

    it 'stays quiet on the first confirmation and tells the other party once the trade completes' do
      transition('accept', user: recipient)
      transition('complete', user: recipient)
      expect(notified(proposer)).to eq(%w[trade_accepted])

      transition('complete', user: proposer)
      expect(notified(recipient)).to eq(%w[trade_completed])
    end

    it 'notifies nobody about a refused step' do
      transition('accept', user: proposer)

      expect(Notification.count).to eq(0)
    end
  end

  describe '.allowed_events' do
    def allowed(user, on: trade)
      described_class.allowed_events(trade: on, user: user)
    end

    it 'offers the recipient an answer on a proposed trade' do
      expect(allowed(recipient)).to eq(%w[accept decline cancel])
    end

    it 'only lets the proposer withdraw a proposed trade' do
      expect(allowed(proposer)).to eq(%w[cancel])
    end

    it 'offers confirmation on an accepted trade until the party has confirmed' do
      accepted = create(:trade, :half_confirmed, proposer: proposer, recipient: recipient)

      expect(allowed(recipient, on: accepted)).to eq(%w[cancel complete])
      expect(allowed(proposer, on: accepted)).to eq(%w[cancel])
    end

    it 'offers nothing on a closed trade or to an outsider' do
      closed = create(:trade, proposer: proposer, recipient: recipient, status: 'completed')

      expect(allowed(proposer, on: closed)).to be_empty
      expect(allowed(outsider)).to be_empty
    end
  end

  it 'refuses an event that is not part of the state machine' do
    expect(transition('haggle', user: recipient)[:error]).to match(/Unknown trade action/)
  end
end
