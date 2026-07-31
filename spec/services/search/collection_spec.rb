require 'rails_helper'

RSpec.describe Search::Collection, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:boxset) { create(:boxset, code: 'TST') }
  let!(:card_a) { create(:magic_card, name: 'Lightning Bolt', normal_price: 10.0, boxset: boxset) }
  let!(:card_b) { create(:magic_card, name: 'Dark Ritual', normal_price: 5.0) }

  before do
    create(:collection_magic_card, collection: collection, magic_card: card_a, quantity: 2, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card_b, quantity: 1, foil_quantity: 0)
  end

  let(:cards) do
    MagicCard.joins(:collection_magic_cards).where(collection_magic_cards: { collection_id: collection.id })
  end

  context 'searching by name' do
    it 'filters to matching cards' do
      result = described_class.call(cards: cards, search_term: 'Lightning', sort_by: :price)
      expect(result.map(&:name)).to include('Lightning Bolt')
      expect(result.map(&:name)).not_to include('Dark Ritual')
    end
  end

  context 'sorting by price' do
    it 'orders by normal_price DESC' do
      result = described_class.call(cards: cards, search_term: '', sort_by: :price)
      expect(result.first.name).to eq('Lightning Bolt')
    end

    it 'ranks a foil-only printing by its foil price' do
      foil_card = create(:magic_card, name: 'Mystical Archive', normal_price: 1.0, foil_price: 70.55)
      create(:collection_magic_card, collection: collection, magic_card: foil_card, quantity: 0, foil_quantity: 1)

      result = described_class.call(cards: cards, search_term: '', sort_by: :price)
      expect(result.first.name).to eq('Mystical Archive')
    end

    it 'ignores the foil price of a printing owned only in regular' do
      pricey_foil = create(:magic_card, name: 'Cheap Normal', normal_price: 1.0, foil_price: 500.0)
      create(:collection_magic_card, collection: collection, magic_card: pricey_foil, quantity: 1, foil_quantity: 0)

      result = described_class.call(cards: cards, search_term: '', sort_by: :price)
      expect(result.map(&:name)).to eq(['Lightning Bolt', 'Dark Ritual', 'Cheap Normal'])
    end

    it 'sorts a printing with no normal price by its foil price' do
      no_normal = create(:magic_card, name: 'Foil Only', normal_price: nil, foil_price: 7.5)
      create(:collection_magic_card, collection: collection, magic_card: no_normal, quantity: 0, foil_quantity: 2)

      result = described_class.call(cards: cards, search_term: '', sort_by: :price)
      expect(result.map(&:name)).to eq(['Lightning Bolt', 'Foil Only', 'Dark Ritual'])
    end
  end

  context 'sorting by card number' do
    it 'sorts numerically' do
      result = described_class.call(cards: cards, search_term: '', sort_by: :id)
      expect(result).to be_a(Array)
    end
  end

  context 'with an unknown sort_by' do
    it 'returns the relation rather than nil' do
      result = described_class.call(cards: cards, search_term: '', sort_by: :nonsense)
      expect(result.map(&:name)).to contain_exactly('Lightning Bolt', 'Dark Ritual')
    end
  end

  context 'filtering by boxset code' do
    it 'returns only cards from that set' do
      result = described_class.call(cards: cards, search_term: '', sort_by: :price, code: 'TST')
      expect(result.map(&:name)).to include('Lightning Bolt')
    end
  end
end
