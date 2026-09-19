require 'rails_helper'

RSpec.describe CollectionTrades::List, type: :service do
  let(:user) { create(:user, username: 'trader') }
  let(:binder) { create(:collection, user: user, is_public: true) }
  let(:vault) { create(:collection, user: user, is_public: false) }

  let(:lotus) do
    create(:magic_card, name: 'Black Lotus', normal_price: 10, foil_price: 30,
                        ck_buylist_normal_price: 6, ck_buylist_foil_price: 20, mana_value: 0)
  end
  let(:bolt) do
    create(:magic_card, name: 'Lightning Bolt', normal_price: 2, foil_price: 5,
                        ck_buylist_normal_price: 1, ck_buylist_foil_price: 3, mana_value: 1)
  end
  let(:ritual) { create(:magic_card, name: 'Dark Ritual', normal_price: 1, foil_price: 2) }

  before do
    create(:collection_magic_card, collection: binder, magic_card: lotus, quantity: 3, trade_quantity: 1)
    create(:collection_magic_card, collection: binder, magic_card: bolt, quantity: 2, foil_quantity: 1,
                                   trade_quantity: 2, trade_foil_quantity: 1)
    # owned but not offered
    create(:collection_magic_card, collection: binder, magic_card: ritual, quantity: 4)
  end

  def list(**)
    described_class.call(user: user, **)
  end

  def names(**)
    list(**)[:cards].map(&:name)
  end

  it 'lists only printings with copies marked for trade' do
    expect(names).to contain_exactly('Black Lotus', 'Lightning Bolt')
  end

  it 'leaves out copies marked for trade in a private collection' do
    create(:collection_magic_card, collection: vault, magic_card: ritual, quantity: 1, trade_quantity: 1)

    expect(names).not_to include('Dark Ritual')
    expect(list[:totals][:copies]).to eq(4)
  end

  it 'sums trade quantities across public collections into one row' do
    other = create(:collection, user: user, is_public: true)
    create(:collection_magic_card, collection: other, magic_card: lotus, quantity: 1, foil_quantity: 1,
                                   trade_quantity: 1, trade_foil_quantity: 1)

    row = CollectionQuery::PageRows.call(cards: list[:cards]).find { |card| card.name == 'Black Lotus' }

    expect([row.trade_quantity, row.trade_foil_quantity]).to eq([2, 1])
  end

  it 'prices each finish at its own retail and buylist column' do
    # lotus 1 x 10; bolt 2 x 2 + 1 x 5
    expect(list[:totals]).to eq(copies: 4, retail: 19.to_d, buylist: 11.to_d)
  end

  it 'totals zero for a user with nothing on offer' do
    expect(described_class.call(user: create(:user, username: 'empty'))[:totals])
      .to eq(copies: 0, retail: 0.to_d, buylist: 0.to_d)
  end

  it 'counts printings per finish' do
    expect(list[:counts]).to eq(all: 2, regular: 2, foil: 1)
  end

  it 'narrows to printings with foil copies on offer' do
    expect(names(finish: 'foil')).to contain_exactly('Lightning Bolt')
  end

  it 'searches by name' do
    expect(names(search: 'lotus')).to contain_exactly('Black Lotus')
  end

  describe 'sorting' do
    before do
      recall = create(:magic_card, name: 'Ancestral Recall', normal_price: 0.5, mana_value: 2)
      create(:collection_magic_card, collection: binder, magic_card: recall, quantity: 1, trade_quantity: 1)
    end

    it 'puts the most valuable printing first by default' do
      expect(names).to eq(['Black Lotus', 'Lightning Bolt', 'Ancestral Recall'])
    end

    it 'sorts by name' do
      expect(names(sort: 'name')).to eq(['Ancestral Recall', 'Black Lotus', 'Lightning Bolt'])
    end

    it 'sorts by mana value' do
      expect(names(sort: 'mana')).to eq(['Black Lotus', 'Lightning Bolt', 'Ancestral Recall'])
    end
  end

  it 'falls back to the defaults for unknown options' do
    expect(names(finish: 'etched', sort: 'DROP TABLE')).to contain_exactly('Black Lotus', 'Lightning Bolt')
  end

  it 'does not hand another user the rows' do
    stranger = create(:user, username: 'stranger')
    theirs = create(:collection, user: stranger, is_public: true)
    create(:collection_magic_card, collection: theirs, magic_card: ritual, quantity: 1, trade_quantity: 1)

    expect(names).not_to include('Dark Ritual')
  end
end
