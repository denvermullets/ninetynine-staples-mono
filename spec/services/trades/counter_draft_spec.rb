require 'rails_helper'

RSpec.describe Trades::CounterDraft, type: :service do
  let(:proposer) { create(:user, username: 'proposer', trades_public: true) }
  let(:recipient) { create(:user, username: 'recipient', trades_public: true) }
  let(:lotus) { create(:magic_card, name: 'Black Lotus') }
  let(:bolt) { create(:magic_card, name: 'Lightning Bolt') }
  let(:original) { create(:trade, proposer: proposer, recipient: recipient) }

  def binder_row(user, magic_card, **counts)
    collection = create(:collection, user: user, is_public: true)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card, quantity: 4,
                                     foil_quantity: 2, trade_quantity: 4, trade_foil_quantity: 2 }.merge(counts))
  end

  def offer(row, side, quantity: 1, foil_quantity: 0)
    create(:trade_item, trade: original, collection_magic_card: row, magic_card: row.magic_card, side: side,
                        quantity: quantity, foil_quantity: foil_quantity)
  end

  # the builder's rows as the counter-offer sees them: the recipient is now the one proposing
  def draft
    held = original.reload.trade_items.filter_map(&:collection_magic_card_id)
    rows = Trades::AvailableRows.call(user: proposer, except_trade: original, also: held) +
           Trades::AvailableRows.call(user: recipient, except_trade: original, also: held)
    described_class.call(parent: original.reload, rows: rows)
  end

  it 'starts every row at the copies the original trade put on it, on both sides' do
    mine = binder_row(proposer, lotus)
    theirs = binder_row(recipient, bolt)
    offer(mine, 'proposer', quantity: 2, foil_quantity: 1)
    offer(theirs, 'recipient', quantity: 3)

    expect(draft).to eq(mine.id => { quantity: 2, foil_quantity: 1 }, theirs.id => { quantity: 3, foil_quantity: 0 })
  end

  it 'caps a row at what it can offer now' do
    mine = binder_row(proposer, lotus)
    offer(mine, 'proposer', quantity: 4)
    mine.update!(quantity: 1, trade_quantity: 1)

    expect(draft[mine.id]).to eq(quantity: 1, foil_quantity: 0)
  end

  it 'keeps a card that has since come off the trade list - the copies are still there to ask for' do
    mine = binder_row(proposer, lotus)
    offer(mine, 'proposer')
    mine.update!(trade_quantity: 0, trade_foil_quantity: 0)

    expect(draft).to eq(mine.id => { quantity: 1, foil_quantity: 0 })
  end

  it 'drops a card whose collection has since gone private' do
    mine = binder_row(proposer, lotus)
    offer(mine, 'proposer')
    mine.collection.update!(is_public: false)

    expect(draft).to be_empty
  end

  it 'drops an item whose collection row was deleted' do
    create(:trade_item, trade: original, collection_magic_card: nil, magic_card: lotus, side: 'proposer')

    expect(draft).to be_empty
  end
end
