require 'rails_helper'

RSpec.describe Collections::VisualModeSetup, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, rarity: 'rare') }

  before do
    create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: 2, foil_quantity: 0)
  end

  # the paginated page, not a relation - see the note on the service
  let(:cards) { [magic_card] }

  context 'with no grouping' do
    it 'returns aggregated quantities and nil grouped_cards' do
      result = described_class.call(cards: cards, user: user, grouping: 'none')
      expect(result[:aggregated_quantities][magic_card.id][:total_quantity]).to eq(2)
      expect(result[:grouped_cards]).to be_nil
    end
  end

  context 'with rarity grouping' do
    it 'returns grouped cards' do
      result = described_class.call(cards: cards, user: user, grouping: 'rarity')
      expect(result[:grouped_cards]).to be_a(Hash)
      expect(result[:grouped_cards].keys).to include('Rare')
    end
  end

  context 'when a collection is selected' do
    let(:other_collection) { create(:collection, user: user) }

    before do
      create(:collection_magic_card, collection: other_collection, magic_card: magic_card, quantity: 5)
    end

    it 'narrows the quantities to that collection' do
      result = described_class.call(cards: cards, user: user, grouping: 'none',
                                    collection_id: collection.id)

      expect(result[:aggregated_quantities][magic_card.id][:total_quantity]).to eq(2)
    end

    it 'sums across collections without one' do
      result = described_class.call(cards: cards, user: user, grouping: 'none')

      expect(result[:aggregated_quantities][magic_card.id][:total_quantity]).to eq(7)
    end
  end
end
