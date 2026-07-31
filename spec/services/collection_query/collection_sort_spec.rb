require 'rails_helper'

RSpec.describe CollectionQuery::CollectionSort, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let!(:card_a) do
    create(:magic_card, name: 'Lightning Bolt', card_number: '10', normal_price: 10.0, ck_buylist_normal_price: 1.0)
  end
  let!(:card_b) do
    create(:magic_card, name: 'Dark Ritual', card_number: '2', normal_price: 5.0, ck_buylist_normal_price: 4.0)
  end

  before do
    create(:collection_magic_card, collection: collection, magic_card: card_a, quantity: 2, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card_b, quantity: 1, foil_quantity: 0)
  end

  # the grouped, owned-price ordered relation the collections controller hands over
  let(:cards) do
    Search::Collection.call(
      cards: MagicCard.joins(:collection_magic_cards).where(collection_magic_cards: { collection_id: collection.id }),
      search_term: '', sort_by: :price
    )
  end

  context 'with no column' do
    it 'keeps the owned price ordering' do
      result = described_class.call(cards: cards, column: nil)
      expect(result.map(&:name)).to eq(['Lightning Bolt', 'Dark Ritual'])
    end

    it 'keeps the owned price ordering for the default pseudo column' do
      result = described_class.call(cards: cards, column: 'owned_price')
      expect(result.map(&:name)).to eq(['Lightning Bolt', 'Dark Ritual'])
    end
  end

  context 'with a magic_cards column' do
    it 'sorts by name ascending' do
      result = described_class.call(cards: cards, column: 'name', direction: 'asc')
      expect(result.map(&:name)).to eq(['Dark Ritual', 'Lightning Bolt'])
    end

    it 'sorts by a buylist price descending' do
      result = described_class.call(cards: cards, column: 'ck_buylist_normal_price', direction: 'desc')
      expect(result.map(&:name)).to eq(['Dark Ritual', 'Lightning Bolt'])
    end

    it 'keeps the grouping and quantity aliases the table view depends on' do
      result = described_class.call(cards: cards, column: 'name', direction: 'asc')

      expect(result.group_values).to be_present
      expect(result.map { |card| card.quantity.to_i }).to eq([1, 2])
    end

    it 'falls back to the owned price ordering for a column that is not allowed' do
      result = described_class.call(cards: cards, column: 'drop table', direction: 'asc')
      expect(result.map(&:name)).to eq(['Lightning Bolt', 'Dark Ritual'])
    end
  end

  context 'with card_number' do
    it 'sorts numerically rather than alphabetically' do
      result = described_class.call(cards: cards, column: 'card_number', direction: 'asc')
      expect(result.map(&:name)).to eq(['Dark Ritual', 'Lightning Bolt'])
    end

    it 'reverses on desc' do
      result = described_class.call(cards: cards, column: 'card_number', direction: 'desc')
      expect(result.map(&:name)).to eq(['Lightning Bolt', 'Dark Ritual'])
    end

    it 'places card numbers with no digits last' do
      lettered = create(:magic_card, name: 'Token Beast', card_number: 'TB')
      create(:collection_magic_card, collection: collection, magic_card: lettered, quantity: 1)

      result = described_class.call(cards: cards, column: 'card_number', direction: 'asc')
      expect(result.map(&:name)).to eq(['Dark Ritual', 'Lightning Bolt', 'Token Beast'])
    end
  end

  context 'with a color filter applied on top' do
    it 'survives the DISTINCT the filter adds' do
      red = Color.create!(name: 'R')
      MagicCardColor.create!(magic_card: card_a, color: red)

      filtered = CollectionQuery::Filter.call(
        cards: described_class.call(cards: cards, column: 'card_number', direction: 'asc'),
        colors: ['R']
      )

      expect(filtered.map(&:name)).to eq(['Lightning Bolt'])
    end
  end
end
