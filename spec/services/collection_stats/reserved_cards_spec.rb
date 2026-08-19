require 'rails_helper'

RSpec.describe CollectionStats::ReservedCards, type: :service do
  subject(:rows) { call[:rows] }

  let(:collection) { create(:collection) }
  let(:set) { create(:boxset, code: 'ALP', name: 'Alpha', release_date: '1993-08-05') }

  def call(filter: 'all', sort: 'name', unit: 'printing', collections: [collection])
    described_class.call(collection_ids: collections.map(&:id), filter: filter, sort: sort,
                         unit: unit)
  end

  # the factory names every card Black Lotus and leaves scryfall_oracle_id nil, so anything asking a
  # question about CARDS rather than printings has to be explicit about which is which
  def reserved(name, oracle: SecureRandom.uuid, boxset: set, **attributes)
    create(:magic_card, { boxset: boxset, name: name, scryfall_oracle_id: oracle,
                          is_reserved: true, normal_price: 100 }.merge(attributes))
  end

  def own(magic_card, target: collection, **attributes)
    create(:collection_magic_card, { collection: target, magic_card: magic_card,
                                     quantity: 1 }.merge(attributes))
  end

  describe 'which printings it reports on' do
    it 'lists reserved printings and leaves everything else out' do
      reserved('Gaeas Cradle')
      create(:magic_card, boxset: set, name: 'Lightning Bolt')

      expect(rows.map { |row| row[:name] }).to eq(['Gaeas Cradle'])
    end

    it 'leaves out tokens and the back faces of double-faced cards' do
      reserved('Reserved Token', is_token: true)
      reserved('Reserved Back', card_side: 'b')
      reserved('Reserved Front', card_side: 'a')

      expect(rows.map { |row| row[:name] }).to eq(['Reserved Front'])
    end

    it 'carries the set the printing came from, which is what the tile badges' do
      reserved('Gaeas Cradle', boxset: create(:boxset, code: 'USG', name: 'Urzas Saga'))

      expect(rows.first).to include(set_code: 'USG', set_name: 'Urzas Saga')
    end
  end

  describe 'what counts as owned' do
    it 'counts a real copy in any of the collections passed in' do
      other = create(:collection)
      own(reserved('Gaeas Cradle'), target: other)

      expect(call(collections: [collection, other])[:rows].first).to include(owned: true, copies: 1)
    end

    it 'counts a foil copy' do
      own(reserved('Gaeas Cradle'), quantity: 0, foil_quantity: 1)

      expect(rows.first).to include(owned: true, copies: 1)
    end

    # PROXIES ARE NOT COLLECTED - this page exists to say what is left to buy, and a proxy is the
    # thing you print because you have not bought it
    it 'reads a printing held only as a proxy as missing' do
      own(reserved('Gaeas Cradle'), quantity: 0, proxy_quantity: 2)

      expect(rows.first).to include(owned: false, copies: 0)
    end

    it 'ignores staged and wishlisted rows' do
      own(reserved('Gaeas Cradle'), staged: true)
      own(reserved('Mox Diamond'), needed: true)

      expect(rows.map { |row| row[:owned] }).to eq([false, false])
    end
  end

  describe 'filters' do
    before do
      own(reserved('Gaeas Cradle'))
      reserved('Mox Diamond')
    end

    it 'narrows to what is owned' do
      expect(call(filter: 'owned')[:rows].map { |row| row[:name] }).to eq(['Gaeas Cradle'])
    end

    it 'narrows to what is missing' do
      expect(call(filter: 'missing')[:rows].map { |row| row[:name] }).to eq(['Mox Diamond'])
    end

    # counted off every row rather than the filtered list, so the toggle can label all three of its
    # buttons and switching filter does not make the collection look like it shrank
    it 'counts every row regardless of which filter is on' do
      expect(call(filter: 'missing')[:counts]).to eq(all: 2, owned: 1, missing: 1)
    end

    it 'falls back to all when handed a filter it does not have' do
      expect(call(filter: 'nonsense')[:rows].size).to eq(2)
    end
  end

  describe 'sorts' do
    let(:newer) { create(:boxset, release_date: '1999-02-15') }

    before do
      reserved('Mox Diamond', normal_price: 40)
      reserved('Gaeas Cradle', normal_price: 300, boxset: newer)
    end

    it 'sorts by name' do
      expect(call(sort: 'name')[:rows].map { |row| row[:name] }).to eq(['Gaeas Cradle', 'Mox Diamond'])
    end

    it 'sorts by price, dearest first' do
      expect(call(sort: 'price')[:rows].map { |row| row[:name] }).to eq(['Gaeas Cradle', 'Mox Diamond'])
    end

    it 'sorts by set, newest first' do
      expect(call(sort: 'set')[:rows].map { |row| row[:name] }).to eq(['Gaeas Cradle', 'Mox Diamond'])
    end

    it 'falls back to name when handed a sort it does not have' do
      expect(call(sort: 'nonsense')[:rows].map { |row| row[:name] }).to eq(['Gaeas Cradle', 'Mox Diamond'])
    end
  end

  describe 'totals' do
    subject(:totals) { call[:totals] }

    let(:cradle) { SecureRandom.uuid }
    let(:mox) { SecureRandom.uuid }

    # two cards, four printings, one printing held - the two units have to disagree here or the page
    # is reporting the same number twice
    before do
      own(reserved('Gaeas Cradle', oracle: cradle, normal_price: 300))
      reserved('Gaeas Cradle', oracle: cradle, normal_price: 250)
      reserved('Mox Diamond', oracle: mox, normal_price: 40)
      reserved('Mox Diamond', oracle: mox, normal_price: 60)
    end

    it 'reports completion at both card and printing level' do
      expect(totals).to include(printings_total: 4, printings_owned: 1,
                                cards_total: 2, cards_owned: 1, cards_share: 50.0)
    end

    it 'values only the real copies held' do
      expect(totals[:value_owned]).to eq(300)
    end

    # the cheapest printing of each card you hold NONE of. A card already held costs nothing to
    # finish, so the second Gaeas Cradle printing is not in this number.
    it 'prices the cheapest printing of each card still missing' do
      expect(totals[:cost_to_complete]).to eq(40)
    end

    it 'skips printings with no price rather than counting them as free' do
      reserved('Timetwister', normal_price: 0, foil_price: 0)

      expect(totals[:cost_to_complete]).to eq(40)
    end

    # a printing with no oracle id is its own card rather than silently merging with every other
    # null, the same fallback SetCards uses
    it 'groups printings with no oracle id by name' do
      reserved('Juzam Djinn', oracle: nil, normal_price: 500)
      reserved('Juzam Djinn', oracle: nil, normal_price: 700)

      expect(totals).to include(cards_total: 3, printings_total: 6)
    end
  end

  # COLUMNS is plucked positionally and zipped onto KEYS, so a column added to one and not the other
  # shifts every field after it into the wrong key - silently, and only on the page
  it 'keeps the plucked columns and their names in step' do
    expect(described_class::KEYS.size).to eq(described_class::COLUMNS.size)
  end

  describe 'at card unit' do
    subject(:cards) { call(unit: 'card')[:rows] }

    let(:oracle) { SecureRandom.uuid }
    let(:newer) { create(:boxset, code: 'REV', name: 'Revised', release_date: '1994-04-01') }

    it 'folds every printing of a card under one row' do
      own(reserved('Underground Sea', oracle: oracle))
      reserved('Underground Sea', oracle: oracle, boxset: newer)

      expect(cards.size).to eq(1)
      expect(cards.first).to include(name: 'Underground Sea', owned_printings: 1,
                                     total_printings: 2, owned: true, incomplete: true)
    end

    # the ORIGINAL printing names and prices the row, whichever way the list is sorted, or the same
    # card would look like a different row under a different sort
    it 'speaks for the card with its earliest printing' do
      reserved('Underground Sea', oracle: oracle, boxset: newer, normal_price: 900)
      reserved('Underground Sea', oracle: oracle, normal_price: 400)

      expect(call(unit: 'card', sort: 'price')[:rows].first[:primary]).to include(set_code: 'ALP')
    end

    # straight earliest-release picks memorabilia: Abeyance's oversized league prize is dated ten
    # days before Weatherlight, and naming that as the card's original printing is wrong
    it 'passes over memorabilia when a real printing exists' do
      oversized = create(:boxset, code: 'OLEP', release_date: '1997-05-30', set_type: 'memorabilia')
      reserved('Abeyance', oracle: oracle, boxset: oversized)
      reserved('Abeyance', oracle: oracle, boxset: create(:boxset, code: 'WTH',
                                                                   release_date: '1997-06-09',
                                                                   set_type: 'expansion'))

      expect(cards.first[:primary]).to include(set_code: 'WTH')
    end

    it 'still names a primary when every printing is memorabilia' do
      reserved('Abeyance', oracle: oracle,
                           boxset: create(:boxset, code: 'OLEP', release_date: '1997-05-30',
                                                   set_type: 'memorabilia'))

      expect(cards.first[:primary]).to include(set_code: 'OLEP')
    end

    it 'sums the copies held across every printing' do
      own(reserved('Underground Sea', oracle: oracle), quantity: 2)
      own(reserved('Underground Sea', oracle: oracle, boxset: newer), quantity: 0, foil_quantity: 1)

      expect(cards.first).to include(owned_qty: 2, owned_foil_qty: 1, owned_printings: 2,
                                     incomplete: false)
    end

    # owned and missing are not opposites here, the same rule SetCards follows - a card at 1 of 2 is
    # one you have AND one you are still shopping for, and it belongs in both lists
    it 'puts a partly-held card in both the owned and the missing list' do
      own(reserved('Underground Sea', oracle: oracle))
      reserved('Underground Sea', oracle: oracle, boxset: newer)

      expect(call(unit: 'card', filter: 'owned')[:rows].size).to eq(1)
      expect(call(unit: 'card', filter: 'missing')[:rows].size).to eq(1)
    end

    it 'counts cards rather than printings' do
      reserved('Underground Sea', oracle: oracle)
      reserved('Underground Sea', oracle: oracle, boxset: newer)

      expect(call(unit: 'card')[:counts]).to eq(all: 1, owned: 0, missing: 1)
      expect(call(unit: 'printing')[:counts]).to eq(all: 2, owned: 0, missing: 2)
    end

    # the header is about the list, not the view - a completion figure that moved when you clicked
    # Table would be reporting on the table
    it 'reports the same totals whichever unit is asked for' do
      own(reserved('Underground Sea', oracle: oracle))
      reserved('Underground Sea', oracle: oracle, boxset: newer)

      expect(call(unit: 'card')[:totals]).to eq(call(unit: 'printing')[:totals])
    end

    it 'falls back to printings when handed a unit it does not have' do
      reserved('Underground Sea', oracle: oracle)
      reserved('Underground Sea', oracle: oracle, boxset: newer)

      expect(call(unit: 'nonsense')[:rows].size).to eq(2)
    end
  end

  it 'returns nothing when the viewer can see no collections' do
    reserved('Gaeas Cradle')

    expect(call(collections: [])[:rows].map { |row| row[:owned] }).to eq([false])
  end
end
