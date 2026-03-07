require 'rails_helper'

RSpec.describe CollectionQuery::Sort, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let!(:card_a) { create(:magic_card, name: 'Alpha', card_number: '1', normal_price: 10.0) }
  let!(:card_b) { create(:magic_card, name: 'Beta', card_number: '2', normal_price: 5.0) }
  let!(:card_c) { create(:magic_card, name: 'Gamma', card_number: 'A3', normal_price: 20.0) }

  before do
    create(:collection_magic_card, collection: collection, magic_card: card_a, quantity: 1, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card_b, quantity: 2, foil_quantity: 0)
    create(:collection_magic_card, collection: collection, magic_card: card_c, quantity: 1, foil_quantity: 0)
  end

  let(:cards) { MagicCard.where(id: [card_a.id, card_b.id, card_c.id]) }

  context 'when sorting by card number' do
    it 'sorts numeric card numbers first, non-numeric at end' do
      result = described_class.call(cards: cards.to_a, sort_by: :id)
      expect(result.first.name).to eq('Alpha')
      expect(result.last.name).to eq('Gamma')
    end
  end

  context 'when sorting by price' do
    it 'sorts by total_value DESC' do
      result = described_class.call(cards: cards, sort_by: :price)
      names = result.map(&:name)
      expect(names.first).to eq('Gamma')
    end
  end

  context 'with unknown sort_by' do
    it 'returns cards unmodified' do
      result = described_class.call(cards: cards, sort_by: :unknown)
      expect(result).to eq(cards)
    end
  end
end
