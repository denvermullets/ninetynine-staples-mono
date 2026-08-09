require 'rails_helper'

RSpec.describe CollectionQuery::TotalCount, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:other_collection) { create(:collection, user: user) }
  let(:boxset) { create(:boxset, code: 'TST') }

  let!(:bolt) { create(:magic_card, name: 'Lightning Bolt', rarity: 'common', boxset: boxset) }
  let!(:ritual) { create(:magic_card, name: 'Dark Ritual', rarity: 'rare', boxset: create(:boxset)) }

  before do
    create(:collection_magic_card, collection: collection, magic_card: bolt, quantity: 2)
    create(:collection_magic_card, collection: collection, magic_card: ritual, quantity: 1)
    MagicCardColor.create!(magic_card: bolt, color: Color.find_or_create_by!(name: 'R'))
    MagicCardColor.create!(magic_card: ritual, color: Color.find_or_create_by!(name: 'B'))
  end

  def sort_config(params)
    CollectionQuery::SortConfig.new(
      params: params,
      allowed_columns: CollectionSorting::SORT_COLUMNS,
      default_column: CollectionQuery::CollectionSort::DEFAULT_COLUMN
    )
  end

  # the relation the controller actually paginates, built by the same service it uses
  def filtered_cards(**params)
    Collections::CardSearch.call(user: user, params: params, sort_config: sort_config(params))[:cards]
  end

  # the property that matters: whatever pagy would have computed the slow way, we compute the
  # fast way. Asserting parity rather than a literal means a filter added later is covered here
  # without anyone remembering to update this spec
  def expect_parity(relation)
    expect(described_class.call(cards: relation)).to eq(relation.count(:all).size)
  end

  it 'counts the unfiltered relation' do
    relation = filtered_cards
    expect(described_class.call(cards: relation)).to eq(2)
    expect_parity(relation)
  end

  it 'counts each card once when it lives in more than one collection' do
    create(:collection_magic_card, collection: other_collection, magic_card: bolt, quantity: 3)
    relation = filtered_cards

    expect(described_class.call(cards: relation)).to eq(2)
    expect_parity(relation)
  end

  it 'returns zero when nothing matches' do
    relation = filtered_cards(search: 'nothing named this')

    expect(described_class.call(cards: relation)).to eq(0)
    expect_parity(relation)
  end

  context 'with the proxy HAVING clause' do
    let!(:proxy_only) { create(:magic_card, name: 'Proxy Mox', rarity: 'rare', boxset: boxset) }

    before do
      create(:collection_magic_card, collection: collection, magic_card: proxy_only,
                                     quantity: 0, foil_quantity: 0, proxy_quantity: 4)
    end

    # hide_proxies is the default - only the literal string 'false' turns it off
    it 'excludes proxy-only cards by default' do
      relation = filtered_cards

      expect(described_class.call(cards: relation)).to eq(2)
      expect_parity(relation)
    end

    it 'includes proxy-only cards when hide_proxies is off' do
      relation = filtered_cards(hide_proxies: 'false')

      expect(described_class.call(cards: relation)).to eq(3)
      expect_parity(relation)
    end
  end

  context 'with column filters' do
    it 'counts a rarity filter' do
      relation = filtered_cards(rarity: ['rare'])

      expect(described_class.call(cards: relation)).to eq(1)
      expect_parity(relation)
    end

    it 'counts a price change filter' do
      bolt.update_column(:price_change_weekly_normal, 15.0)
      ritual.update_column(:price_change_weekly_normal, 2.0)
      relation = filtered_cards(price_change_range: '10.0,20.0')

      expect(described_class.call(cards: relation)).to eq(1)
      expect_parity(relation)
    end

    # the colors filter is an IN subquery rather than a join, so it narrows the group without
    # adding DISTINCT - the count stays a plain COUNT(*) OVER () over the same groups
    it 'counts a colors filter' do
      relation = filtered_cards(mana: ['R'])

      expect(relation.distinct_value).to be_falsey
      expect(described_class.call(cards: relation)).to eq(1)
      expect_parity(relation)
    end
  end

  context 'with advanced query terms' do
    it 'counts an ownership term applied as HAVING' do
      relation = filtered_cards(search: 'qty>=2')

      expect(described_class.call(cards: relation)).to eq(1)
      expect_parity(relation)
    end

    it 'counts a card level term applied as a subquery' do
      relation = filtered_cards(search: 's:TST')

      expect(described_class.call(cards: relation)).to eq(1)
      expect_parity(relation)
    end
  end

  # pick replaces the select list, so the count has to drop the card_number sort's ORDER BY
  # expression along with it
  it 'counts a relation ordered by card number' do
    relation = filtered_cards(sort: 'card_number', direction: 'asc')

    expect { described_class.call(cards: relation) }.not_to raise_error
    expect(described_class.call(cards: relation)).to eq(2)
  end

  context 'without a GROUP BY' do
    it 'falls back to a plain count' do
      expect(described_class.call(cards: MagicCard.where(rarity: 'rare'))).to eq(1)
    end

    it 'sizes an array' do
      expect(described_class.call(cards: [bolt, ritual])).to eq(2)
    end
  end
end
