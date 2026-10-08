require 'rails_helper'

RSpec.describe CollectionStats::SellList, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id], filters: filters) }

  let(:collection) { create(:collection) }
  let(:filters) { {} }

  # the foil buylist rides in card_attrs as ck_buylist_foil_price, and is 0 - not buying - unless given
  def add(name, buylist: 1, quantity: 1, foil_quantity: 0, **card_attrs)
    card = create(:magic_card, name: name, normal_price: 2, foil_price: 4, ck_buylist_normal_price: buylist,
                               ck_buylist_foil_price: 0, **card_attrs)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity,
                                   foil_quantity: foil_quantity)
    card
  end

  def names
    result[:rows].map { |row| row[:name] }
  end

  def row(name, finish = 'normal')
    result[:rows].find { |sell| sell[:name] == name && sell[:finish] == finish }
  end

  describe 'defaults' do
    it 'lists every card CK is buying, biggest payout first, whether or not it moved' do
      add('Two Copies', buylist: 1, quantity: 2)
      add('Big One', buylist: 5)
      add('Small One', buylist: 0.5)

      expect(names).to eq(['Big One', 'Two Copies', 'Small One'])
    end

    it 'reports the filters it applied' do
      expect(result[:filters]).to eq(
        payment: 'cash', finish: 'both', decks: 'skip', min_buylist: nil, max_buylist: nil, rarity: [],
        sort: 'payout', dir: 'desc'
      )
    end
  end

  describe 'the rows' do
    it 'splits a printing into one row per finish held, each with its own copies and payout' do
      boxset = create(:boxset, name: 'Alpha', keyrune_code: 'LEA')
      card = add('Both', buylist: 0.1, quantity: 4, ck_buylist_foil_price: 2, foil_quantity: 1, boxset: boxset,
                         image_small: 'small.jpg', image_large: 'large.jpg')

      expect(row('Both')).to eq(
        id: card.id, name: 'Both', set_name: 'Alpha', icon: 'no-tailwind ss ss-lea ss-fw', rarity: card.rarity,
        image: 'small.jpg', image_large: 'large.jpg', finish: 'normal', copies: 4, buylist: 0.1, payout: 0.4,
        price: 2, places: [{ name: collection.name, copies: 4 }]
      )
      expect(row('Both', 'foil')).to include(copies: 1, buylist: 2, payout: 2, price: 4)
    end

    it 'leaves out a finish CK is not buying and a finish that is not held' do
      add('Foil Only Buy', buylist: 0, quantity: 3, ck_buylist_foil_price: 2, foil_quantity: 1)
      add('Unheld Foil', buylist: 1, quantity: 1, ck_buylist_foil_price: 9, foil_quantity: 0)

      expect(result[:rows].map { |sell| [sell[:name], sell[:finish]] })
        .to contain_exactly(['Foil Only Buy', 'foil'], ['Unheld Foil', 'normal'])
    end

    it 'counts no proxies' do
      card = add('Proxied', buylist: 3, quantity: 0)
      CollectionMagicCard.where(magic_card: card).update_all(proxy_quantity: 4)

      expect(names).to be_empty
    end

    it 'says which collections hold the copies' do
      other = create(:collection, user: collection.user, name: 'Aaa Binder')
      card = add('Split', buylist: 1, quantity: 2)
      create(:collection_magic_card, collection: other, magic_card: card, quantity: 1)

      result = described_class.call(collection_ids: [collection.id, other.id])

      expect(result[:rows].first).to include(
        copies: 3, places: [{ name: 'Aaa Binder', copies: 1 }, { name: collection.name, copies: 2 }]
      )
    end
  end

  describe 'totals' do
    it 'counts rows, copies and payout across every page, not just this one' do
      add('A', buylist: 1, quantity: 2)
      add('B', buylist: 3, ck_buylist_foil_price: 5, foil_quantity: 1)

      result = described_class.call(collection_ids: [collection.id], per_page: 1)

      expect(result).to include(total: 3, copies: 4, payout: 10)
      expect(result[:rows].size).to eq(1)
    end
  end

  describe 'payment' do
    let(:filters) { { payment: 'credit' } }

    it 'adds the store credit bonus to the unit and the payout' do
      add('Credit', buylist: 1, quantity: 3)

      expect(row('Credit')).to include(buylist: 1.3, payout: 3.9)
      expect(result[:payout]).to eq(3.9)
    end

    it 'reads the buylist range in credit, too' do
      add('Under In Cash', buylist: 0.8)
      add('Under In Credit', buylist: 0.7)

      filters.merge!(min_buylist: '1')

      expect(names).to eq(['Under In Cash'])
    end
  end

  describe 'filters' do
    it 'keeps the buylist range, ends included' do
      add('Low', buylist: 0.1)
      add('Edge Low', buylist: 0.15)
      add('Edge High', buylist: 1)
      add('High', buylist: 1.01)

      filters.merge!(min_buylist: '0.15', max_buylist: '1')

      expect(names).to contain_exactly('Edge Low', 'Edge High')
    end

    it 'keeps only the finish picked' do
      add('Both', buylist: 1, ck_buylist_foil_price: 2, foil_quantity: 1)

      filters.merge!(finish: 'foil')

      expect(result[:rows].map { |sell| sell[:finish] }).to eq(['foil'])
    end

    it 'keeps only the rarities picked' do
      add('Common One', rarity: 'common')
      add('Rare One', rarity: 'rare')

      filters.merge!(rarity: ['common'])

      expect(names).to eq(['Common One'])
    end

    it 'leaves the copies in decks out unless asked' do
      deck = create(:collection, user: collection.user, collection_type: 'commander_deck')
      card = add('Binder And Deck', buylist: 1, quantity: 1)
      create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
      deck_only = create(:magic_card, name: 'Deck Only', ck_buylist_normal_price: 1)
      create(:collection_magic_card, collection: deck, magic_card: deck_only, quantity: 1)

      skipped = described_class.call(collection_ids: [collection.id, deck.id])
      included = described_class.call(collection_ids: [collection.id, deck.id], filters: { decks: 'include' })

      expect(skipped[:rows].map { |sell| [sell[:name], sell[:copies]] }).to eq([['Binder And Deck', 1]])
      expect(included[:rows].map { |sell| [sell[:name], sell[:copies]] })
        .to contain_exactly(['Binder And Deck', 2], ['Deck Only', 1])
    end

    it 'falls back to the defaults for values it does not know' do
      filters.merge!(payment: 'gold', finish: 'etched', decks: 'maybe', sort: 'drop table', dir: 'sideways',
                     min_buylist: 'abc', max_buylist: '-1')

      expect(result[:filters]).to include(payment: 'cash', finish: 'both', decks: 'skip', sort: 'payout',
                                          dir: 'desc', min_buylist: nil, max_buylist: nil)
    end
  end

  describe 'sorting' do
    it 'sorts on the unit buylist when asked, smallest first if flipped' do
      add('Many Cheap', buylist: 1, quantity: 10)
      add('One Dear', buylist: 5)

      filters.merge!(sort: 'buylist', dir: 'asc')

      expect(names).to eq(['Many Cheap', 'One Dear'])
    end

    it 'reads names A-Z by default' do
      add('Zed')
      add('Abe')

      filters.merge!(sort: 'name')

      expect(names).to eq(%w[Abe Zed])
    end
  end

  it 'returns nothing for no collections' do
    expect(described_class.call(collection_ids: [])).to include(rows: [], total: 0, copies: 0, payout: 0)
  end
end
