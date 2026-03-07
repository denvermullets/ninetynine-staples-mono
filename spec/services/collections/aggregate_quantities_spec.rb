require 'rails_helper'

RSpec.describe Collections::AggregateQuantities, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card) }

  let!(:cmc) do
    create(:collection_magic_card,
           collection: collection,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 1)
  end

  context 'with owned cards' do
    it 'returns aggregated quantities per card' do
      result = described_class.call(magic_cards: [magic_card], user: user)
      expect(result[magic_card.id][:total_quantity]).to eq(3)
      expect(result[magic_card.id][:total_foil_quantity]).to eq(1)
    end
  end

  context 'with cards across multiple collections' do
    let(:other_collection) { create(:collection, user: user) }

    before do
      create(:collection_magic_card,
             collection: other_collection,
             magic_card: magic_card,
             quantity: 2,
             foil_quantity: 0)
    end

    it 'sums quantities across collections' do
      result = described_class.call(magic_cards: [magic_card], user: user)
      expect(result[magic_card.id][:total_quantity]).to eq(5)
    end
  end

  context 'with no cards' do
    it 'returns empty hash' do
      result = described_class.call(magic_cards: [], user: user)
      expect(result).to eq({})
    end
  end

  context 'with nil user' do
    it 'returns empty hash' do
      result = described_class.call(magic_cards: [magic_card], user: nil)
      expect(result).to eq({})
    end
  end
end
