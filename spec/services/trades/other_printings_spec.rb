require 'rails_helper'

RSpec.describe Trades::OtherPrintings, type: :service do
  let(:user) { create(:user, username: 'trader', trades_public: true) }
  let(:partner) { create(:user, username: 'partner', trades_public: true) }
  let(:binder) { create(:collection, user: user, is_public: true, name: 'Binder') }
  let(:deck) { create(:collection, user: user, is_public: true, name: 'Deck') }
  let(:vault) { create(:collection, user: user, is_public: false, name: 'Vault') }
  let(:oracle_id) { SecureRandom.uuid }
  let(:plst) { create(:magic_card, name: 'Undead Warchief', scryfall_oracle_id: oracle_id) }
  let(:fdc) { create(:magic_card, name: 'Undead Warchief', scryfall_oracle_id: oracle_id) }
  let(:asked_for) { row(plst, collection: deck, quantity: 0, foil_quantity: 1) }

  def row(magic_card, collection: binder, **counts)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card, quantity: 1 }.merge(counts))
  end

  def options(**)
    described_class.call(user: user, row: asked_for, **)
  end

  it 'finds another printing of the card, listed or not' do
    unlisted = row(fdc)
    listed = row(fdc, collection: deck, trade_quantity: 1)

    expect(options.map(&:id)).to contain_exactly(unlisted.id, listed.id)
  end

  it 'finds another copy of the same printing, but not the row being swapped' do
    elsewhere = row(plst)

    expect(options.map(&:id)).to contain_exactly(elsewhere.id)
  end

  it 'leaves out a different card' do
    row(create(:magic_card, name: 'Lightning Bolt', scryfall_oracle_id: SecureRandom.uuid))

    expect(options).to be_empty
  end

  it 'leaves out a copy in a private collection, which a trade could not take' do
    row(fdc, collection: vault)

    expect(options).to be_empty
  end

  it 'leaves out another user\'s copies' do
    row(fdc, collection: create(:collection, user: partner, is_public: true))

    expect(options).to be_empty
  end

  it 'finds nothing for a card with no oracle id, rather than every other card without one' do
    plst.update!(scryfall_oracle_id: nil)
    row(create(:magic_card, name: 'Mystery', scryfall_oracle_id: nil))

    expect(options).to be_empty
  end

  it 'counts copies another open trade holds, except the trade being countered' do
    held = row(fdc)
    trade = create(:trade, proposer: partner, recipient: user)
    create(:trade_item, trade: trade, collection_magic_card: held, magic_card: fdc, side: 'recipient', quantity: 1)

    expect(options).to be_empty
    expect(options(except_trade: trade).map(&:id)).to contain_exactly(held.id)
  end

  it 'stops at the limit' do
    stub_const("#{described_class}::LIMIT", 2)
    3.times { row(create(:magic_card, name: 'Undead Warchief', scryfall_oracle_id: oracle_id)) }

    expect(options.size).to eq(2)
  end
end
