require 'rails_helper'

RSpec.describe Trades::UnlistedRows, type: :service do
  let(:user) { create(:user, username: 'trader', trades_public: true) }
  let(:partner) { create(:user, username: 'partner', trades_public: true) }
  let(:binder) { create(:collection, user: user, is_public: true, name: 'Binder') }
  let(:vault) { create(:collection, user: user, is_public: false, name: 'Vault') }
  let(:path) { create(:magic_card, name: 'Path to Exile') }
  let(:pathbreaker) { create(:magic_card, name: 'Pathbreaker Ibex') }
  let(:bolt) { create(:magic_card, name: 'Lightning Bolt') }

  def row(magic_card, collection: binder, **counts)
    create(:collection_magic_card, { collection: collection, magic_card: magic_card, quantity: 2,
                                     foil_quantity: 1 }.merge(counts))
  end

  def search(query, **)
    described_class.call(user: user, query: query, **)
  end

  it 'finds cards in a public collection that are not marked for trade, by part of the name' do
    row(path)
    row(pathbreaker)
    row(bolt)

    expect(search('PATH').map { |found| found.magic_card.name }).to eq(['Path to Exile', 'Pathbreaker Ibex'])
  end

  it 'hands back every copy owned, with none of them listed' do
    row(path)

    expect(search('path').first).to have_attributes(quantity: 2, foil_quantity: 1, listed_quantity: 0,
                                                    listed_foil_quantity: 0, collection_name: 'Binder')
  end

  it 'leaves out a row that is on the trade list - the builder already shows it' do
    row(path, trade_quantity: 1)

    expect(search('path')).to be_empty
  end

  it 'leaves out a private collection' do
    row(path, collection: vault)

    expect(search('path')).to be_empty
  end

  it 'leaves out another user\'s cards' do
    create(:collection_magic_card, collection: create(:collection, user: partner, is_public: true),
                                   magic_card: path, quantity: 2)

    expect(search('path')).to be_empty
  end

  it 'returns nothing for a blank search rather than the whole collection' do
    row(path)

    expect(search('  ')).to be_empty
  end

  it 'treats a wildcard in the search as the character it is' do
    row(path)

    expect(search('%')).to be_empty
  end

  it 'subtracts copies an open trade already holds' do
    held = row(path)
    trade = create(:trade, proposer: partner, recipient: user)
    create(:trade_item, trade: trade, collection_magic_card: held, magic_card: path, side: 'recipient', quantity: 2)

    expect(search('path').first).to have_attributes(quantity: 0, foil_quantity: 1)
    expect(search('path', except_trade: trade).first).to have_attributes(quantity: 2)
  end

  it 'stops at the limit' do
    stub_const("#{described_class}::LIMIT", 2)
    3.times { |index| row(create(:magic_card, name: "Path #{index}")) }

    expect(search('path').size).to eq(2)
  end
end
