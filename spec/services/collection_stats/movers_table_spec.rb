require 'rails_helper'

RSpec.describe CollectionStats::MoversTable, type: :service do
  subject(:result) { described_class.call(collection_ids: [collection.id], filters: filters) }

  let(:collection) { create(:collection) }
  let(:filters) { {} }

  # price_change_weekly_normal is a percentage, so the dollar move is derived: a $110 card that
  # rose 10% was $100 a week ago and gained $10
  def add(name, price: 100, change: 10, quantity: 1, **card_attrs)
    card = create(:magic_card, name: name, normal_price: price,
                               price_change_weekly_normal: change, **card_attrs)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: quantity)
    card
  end

  def add_foil(name, price: 220, change: 10, foil_quantity: 1, **card_attrs)
    card = create(:magic_card, name: name, normal_price: 0, foil_price: price,
                               price_change_weekly_foil: change, **card_attrs)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: 0,
                                   foil_quantity: foil_quantity)
    card
  end

  def names
    result[:rows].map { |mover| mover[:name] }
  end

  def row(name)
    result[:rows].find { |mover| mover[:name] == name }
  end

  describe 'defaults' do
    it 'ranks every mover on the size of its weekly move' do
      add('Small Gain', price: 110, change: 10)
      add('Big Loss', price: 50, change: -50)
      add('Medium Gain', price: 120, change: 20)

      expect(names).to eq(['Big Loss', 'Medium Gain', 'Small Gain'])
    end

    it 'reports the filters it applied' do
      expect(result[:filters]).to eq(
        window: 'weekly', direction: 'both', finish: 'both', min_delta: nil, min_percent: nil,
        min_price: nil, min_buylist: nil, max_buylist: nil, rarity: [], sort: 'delta', dir: 'desc'
      )
    end
  end

  describe 'the row' do
    it 'matches the PriceMovers row and adds the per-finish copies and both unit prices' do
      boxset = create(:boxset, name: 'Alpha', keyrune_code: 'LEA')
      card = add('Riser', price: 110, change: 10, quantity: 3, foil_price: 300, boxset: boxset,
                          image_small: 'small.jpg', image_large: 'large.jpg', ck_buylist_normal_price: 70,
                          ck_buylist_foil_price: 180)

      expect(row('Riser')).to eq(
        id: card.id, name: 'Riser', set_name: 'Alpha', icon: 'no-tailwind ss ss-lea ss-fw', rarity: 'rare',
        image: 'small.jpg', image_large: 'large.jpg', copies: 3, qty: 3, foil_qty: 0, value: 330,
        delta: 30,
        percent: 10.0, delta_class: CollectionStats::PriceMovers::GAIN_CLASS,
        normal_price: 110, foil_price: 300, buylist_normal: 70, buylist_foil: 180
      )
    end

    it 'adds the foil move to the non-foil move on the same card' do
      card = create(:magic_card, name: 'Both Finishes', normal_price: 110,
                                 price_change_weekly_normal: 10, foil_price: 220,
                                 price_change_weekly_foil: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     foil_quantity: 1)

      expect(row('Both Finishes')).to include(delta: 30, value: 330, percent: 10.0)
    end
  end

  describe 'window' do
    let(:filters) { { window: 'daily' } }

    it 'reads the daily change columns' do
      add('Daily Riser', price: 110, change: nil, price_change_daily_normal: 10)
      add('Weekly Riser', price: 110, change: 10)

      expect(names).to eq(['Daily Riser'])
    end

    it 'falls back to weekly for an unknown window' do
      filters[:window] = 'hourly'
      add('Weekly Riser', price: 110, change: 10)

      expect(names).to eq(['Weekly Riser'])
      expect(result[:filters][:window]).to eq('weekly')
    end
  end

  describe 'direction' do
    before do
      add('Riser', price: 110, change: 10)
      add('Faller', price: 90, change: -10)
    end

    it 'keeps only gainers going up' do
      filters[:direction] = 'up'

      expect(names).to eq(['Riser'])
    end

    it 'keeps only losers going down' do
      filters[:direction] = 'down'

      expect(names).to eq(['Faller'])
    end

    it 'keeps both for an unknown direction' do
      filters[:direction] = 'sideways'

      expect(names).to contain_exactly('Riser', 'Faller')
    end
  end

  describe 'thresholds' do
    it 'applies min_delta to the size of the holding move' do
      add('Four Copies', price: 110, change: 10, quantity: 4)
      add('Big Loss', price: 50, change: -50)
      add('One Copy', price: 110, change: 10)
      filters[:min_delta] = '40'

      expect(names).to eq(['Big Loss', 'Four Copies'])
    end

    it 'applies min_percent to the size of the holding move' do
      add('Twenty Up', price: 120, change: 20)
      add('Fifty Down', price: 50, change: -50)
      add('Ten Up', price: 110, change: 10)
      filters[:min_percent] = '20'

      expect(names).to eq(['Fifty Down', 'Twenty Up'])
    end

    it 'applies min_price to the unit price of the finish you hold' do
      add('Cheap', price: 2, change: 50)
      add('Pricey', price: 110, change: 10)
      add_foil('Foil Only', price: 220)
      filters[:min_price] = '100'

      expect(names).to contain_exactly('Pricey', 'Foil Only')
    end

    describe 'the buylist range' do
      before do
        add('Low Buylist', ck_buylist_normal_price: 0.10)
        add('Mid Buylist', ck_buylist_normal_price: 0.50)
        add('High Buylist', ck_buylist_normal_price: 3)
        add('Not Buying', ck_buylist_normal_price: 0)
      end

      it 'keeps cards CK buys for at least min_buylist' do
        filters[:min_buylist] = '0.50'

        expect(names).to contain_exactly('Mid Buylist', 'High Buylist')
      end

      it 'keeps cards CK buys for at most max_buylist, leaving out the ones CK is not buying' do
        filters[:max_buylist] = '0.50'

        expect(names).to contain_exactly('Low Buylist', 'Mid Buylist')
      end

      it 'applies both ends together' do
        filters.merge!(min_buylist: '0.25', max_buylist: '1')

        expect(names).to eq(['Mid Buylist'])
      end

      it 'reads the buylist of the finish you hold' do
        add_foil('Foil Buylist', ck_buylist_normal_price: 5, ck_buylist_foil_price: 0.40)
        filters.merge!(min_buylist: '0.25', max_buylist: '1')

        expect(names).to contain_exactly('Mid Buylist', 'Foil Buylist')
      end
    end

    it 'ignores a threshold that is not a positive number' do
      add('Riser', price: 110, change: 10)
      filters.merge!(min_delta: 'lots', min_percent: '-5', min_price: '0')

      expect(names).to eq(['Riser'])
      expect(result[:filters]).to include(min_delta: nil, min_percent: nil, min_price: nil)
    end
  end

  describe 'rarity' do
    before do
      add('Common Mover', rarity: 'common')
      add('Rare Mover', rarity: 'rare')
      add('Mythic Mover', rarity: 'mythic')
      add('No Rarity', rarity: nil)
    end

    it 'keeps every card, one with no rarity included, when none is picked' do
      expect(names).to contain_exactly('Common Mover', 'Rare Mover', 'Mythic Mover', 'No Rarity')
    end

    it 'keeps only the rarities picked' do
      filters[:rarity] = %w[mythic rare]

      expect(names).to contain_exactly('Rare Mover', 'Mythic Mover')
    end

    it 'reports the pick in its own order and drops a rarity it does not know' do
      filters[:rarity] = %w[mythic bogus common]

      expect(result[:filters][:rarity]).to eq(%w[common mythic])
    end
  end

  describe 'finish' do
    let!(:card) do
      card = create(:magic_card, name: 'Both Finishes', normal_price: 110,
                                 price_change_weekly_normal: 10, foil_price: 220,
                                 price_change_weekly_foil: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2,
                                     foil_quantity: 1)
      card
    end

    it 'prices only the non-foil copies for normal' do
      filters[:finish] = 'normal'

      expect(row('Both Finishes')).to include(copies: 2, value: 220, delta: 20, percent: 10.0)
    end

    it 'prices only the foil copies for foil' do
      filters[:finish] = 'foil'

      expect(row('Both Finishes')).to include(copies: 1, qty: 0, foil_qty: 1, value: 220, delta: 20,
                                              percent: 10.0)
    end

    it 'drops a card held only in the other finish' do
      add('Non-foil Only', price: 110, change: 10)
      filters[:finish] = 'foil'

      expect(names).to eq(['Both Finishes'])
    end

    it 'falls back to both for an unknown finish' do
      filters[:finish] = 'etched'

      expect(row('Both Finishes')).to include(copies: 3, delta: 40)
    end
  end

  describe 'sort' do
    before do
      add('Alpha', price: 10, change: 100, quantity: 1)
      add('Bravo', price: 300, change: -25, quantity: 1)
      add('Charlie', price: 120, change: 20, quantity: 4)
    end

    it 'sorts on percent, by size' do
      filters[:sort] = 'percent'

      expect(names).to eq(%w[Alpha Bravo Charlie])
    end

    it 'sorts on value' do
      filters[:sort] = 'value'

      expect(names).to eq(%w[Charlie Bravo Alpha])
    end

    it 'sorts on unit price' do
      filters[:sort] = 'price'

      expect(names).to eq(%w[Bravo Charlie Alpha])
    end

    it 'sorts on the CK buylist of the finish held, CK not buying last' do
      add('Buylisted', price: 5, change: 10, ck_buylist_normal_price: 4)
      add('Cheap Buylist', price: 5, change: 10, ck_buylist_normal_price: 0.5)
      filters[:sort] = 'buylist'

      expect(names.first(2)).to eq(['Buylisted', 'Cheap Buylist'])
    end

    it 'sorts on rarity, special and mythic first, a card with no rarity last either way' do
      add('Mythic', change: 1, rarity: 'mythic')
      add('Special', change: 1, rarity: 'special')
      add('Common', change: 1, rarity: 'common')
      add('No Rarity', change: 1, rarity: nil)
      filters[:sort] = 'rarity'

      expect(names.first(2)).to eq(%w[Special Mythic])
      expect(names.last).to eq('No Rarity')

      filters[:dir] = 'asc'
      ascending = described_class.call(collection_ids: [collection.id], filters: filters)[:rows].pluck(:name)
      expect(ascending.first).to eq('Common')
      expect(ascending.last).to eq('No Rarity')
    end

    it 'sorts on name A-Z by default and honours dir' do
      filters[:sort] = 'name'
      expect(names).to eq(%w[Alpha Bravo Charlie])

      filters[:dir] = 'desc'
      expect(described_class.call(collection_ids: [collection.id], filters: filters)[:rows]
        .map { |mover| mover[:name] }).to eq(%w[Charlie Bravo Alpha])
    end

    it 'falls back to the delta sort for an unknown key and direction' do
      filters.merge!(sort: 'magic_cards.id; DROP TABLE users', dir: 'sideways')

      expect(names).to eq(%w[Bravo Charlie Alpha])
      expect(result[:filters]).to include(sort: 'delta', dir: 'desc')
    end
  end

  describe 'what is left out' do
    it 'drops cards whose move rounds to nothing' do
      add('Bulk Common', price: 0.01, change: 5)
      add('Real Mover', price: 110, change: 10)

      expect(names).to eq(['Real Mover'])
    end

    it 'ignores proxy copies - a proxy price did not move' do
      card = create(:magic_card, name: 'Proxied', normal_price: 110,
                                 price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1,
                                     proxy_quantity: 20)

      expect(row('Proxied')).to include(delta: 10, copies: 1, value: 110)
    end

    it 'leaves a proxy-only holding out entirely' do
      card = create(:magic_card, name: 'Proxy Only', normal_price: 110,
                                 price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 0,
                                     proxy_quantity: 4)

      expect(result).to include(rows: [], total: 0)
    end
  end

  describe 'paging' do
    subject(:result) do
      described_class.call(collection_ids: [collection.id], page: page, per_page: 2)
    end

    before { 3.times { |n| add("Card #{n}", price: 110 + n, change: 10 + n) } }

    let(:page) { 2 }

    it 'returns one page of rows and the total across every page' do
      expect(result).to include(total: 3, page: 2, per_page: 2)
      expect(names).to eq(['Card 0'])
    end

    context 'with a page below one' do
      let(:page) { -3 }

      it 'reads the first page' do
        expect(result[:page]).to eq(1)
        expect(names).to eq(['Card 2', 'Card 1'])
      end
    end
  end

  describe '.for_owner' do
    it 'reports on every collection the user owns, private ones included' do
      user = create(:user)
      private_collection = create(:collection, user: user, is_public: false)
      card = create(:magic_card, name: 'Hidden Riser', normal_price: 110,
                                 price_change_weekly_normal: 10)
      create(:collection_magic_card, collection: private_collection, magic_card: card, quantity: 1)

      table = described_class.for_owner(user: user, filters: { 'direction' => 'up' }).call

      expect(table).to include(total: 1, filters: hash_including(direction: 'up'))
    end
  end

  describe 'exclude_card_ids' do
    it 'leaves the excluded cards out of the rows and the total' do
      add('Kept')
      skipped = add('Skipped')

      table = described_class.call(collection_ids: [collection.id], exclude_card_ids: [skipped.id])

      expect(table[:total]).to eq(1)
      expect(table[:rows].map { |mover| mover[:name] }).to eq(['Kept'])
    end
  end

  describe 'an empty scope' do
    it 'returns an empty page without touching the database' do
      queries = []
      subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
        queries << payload[:sql] unless payload[:name].in?(%w[SCHEMA TRANSACTION])
      end

      expect(described_class.call(collection_ids: [])).to include(rows: [], total: 0)
      expect(queries).to be_empty
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
  end
end
