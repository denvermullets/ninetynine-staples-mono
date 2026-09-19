require 'rails_helper'

RSpec.describe Trades::AvailableRows, type: :service do
  let(:user) { create(:user, username: 'trader', trades_public: true) }
  let(:partner) { create(:user, username: 'partner', trades_public: true) }
  let(:binder) { create(:collection, user: user, is_public: true, name: 'Binder') }
  let(:vault) { create(:collection, user: user, is_public: false, name: 'Vault') }
  let(:lotus) { create(:magic_card, name: 'Black Lotus') }
  let(:bolt) { create(:magic_card, name: 'Lightning Bolt') }

  def row(magic_card, collection: binder, **counts)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card,
                                     quantity: 4, foil_quantity: 2, trade_quantity: 4,
                                     trade_foil_quantity: 2 }.merge(counts))
  end

  # an open trade of the user's own, holding some of the copies on the given row
  def open_trade(binder_row, quantity: 1, foil_quantity: 0, status: 'proposed')
    trade = create(:trade, proposer: user, recipient: partner, status: status)
    create(:trade_item, trade: trade, collection_magic_card: binder_row, side: 'proposer',
                        magic_card: binder_row.magic_card, quantity: quantity,
                        foil_quantity: foil_quantity)
    trade
  end

  def rows
    described_class.call(user: user)
  end

  it 'lists a row with the copies it owns, and how many of them are marked for trade' do
    row(lotus, trade_quantity: 3, trade_foil_quantity: 1)

    expect(rows.first).to have_attributes(quantity: 4, foil_quantity: 2, listed_quantity: 3,
                                          listed_foil_quantity: 1, collection_name: 'Binder')
  end

  it 'leaves a row with nothing marked for trade to the search' do
    row(lotus, trade_quantity: 0, trade_foil_quantity: 0)

    expect(rows).to be_empty
  end

  it 'lists an unmarked row it was asked for by id, as unlisted' do
    unmarked = row(lotus, trade_quantity: 0, trade_foil_quantity: 0)

    found = described_class.call(user: user, also: [unmarked.id])

    expect(found.map(&:id)).to eq([unmarked.id])
    expect(found.first).to be_unlisted
  end

  it 'never lists a row in a private collection, asked for or not' do
    hidden = row(lotus, collection: vault)

    expect(described_class.call(user: user, also: [hidden.id])).to be_empty
  end

  it 'never lists proxies or a row with no real copies' do
    row(lotus, quantity: 0, foil_quantity: 0, trade_quantity: 0, trade_foil_quantity: 0, proxy_quantity: 2)

    expect(described_class.call(user: user, scope: user.offerable_cards)).to be_empty
  end

  it 'leaves out copies marked for trade in a private collection' do
    row(lotus, collection: vault)

    expect(rows).to be_empty
  end

  it 'subtracts the copies an open trade already spoke for' do
    open_trade(row(lotus), quantity: 3, foil_quantity: 2)

    expect(rows.first).to have_attributes(quantity: 1, foil_quantity: 0)
  end

  it 'takes committed copies off the trade list before the rest of the row' do
    open_trade(row(lotus, trade_quantity: 1, trade_foil_quantity: 0), quantity: 1)

    expect(rows.first).to have_attributes(quantity: 3, listed_quantity: 0, foil_quantity: 2)
  end

  it 'drops a row whose every copy is already in an open trade' do
    open_trade(row(lotus, quantity: 1, foil_quantity: 0, trade_quantity: 1, trade_foil_quantity: 0), quantity: 1)

    expect(rows).to be_empty
  end

  it 'ignores a trade that is no longer open' do
    open_trade(row(lotus), quantity: 4, foil_quantity: 2, status: 'declined')

    expect(rows.first).to have_attributes(quantity: 4, foil_quantity: 2)
  end

  it 'lists one entry per collection row, not per printing' do
    other_binder = create(:collection, user: user, is_public: true, name: 'Trade Box')
    row(lotus)
    row(lotus, collection: other_binder)

    expect(rows.map(&:collection_name)).to contain_exactly('Binder', 'Trade Box')
  end

  it 'orders by card name' do
    row(lotus)
    row(bolt)

    expect(rows.map { |available| available.magic_card.name }).to eq(['Black Lotus', 'Lightning Bolt'])
  end

  it 'hands back the copies held by the trade being countered' do
    binder_row = row(lotus)
    original = open_trade(binder_row, quantity: 3)
    open_trade(binder_row, quantity: 1)

    expect(described_class.call(user: user, except_trade: original).first).to have_attributes(quantity: 3)
  end
end
