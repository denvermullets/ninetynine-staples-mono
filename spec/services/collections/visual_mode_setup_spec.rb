require 'rails_helper'

RSpec.describe Collections::VisualModeSetup, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, rarity: 'rare') }

  before do
    create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: 2, foil_quantity: 0)
  end

  let(:cards) { MagicCard.where(id: magic_card.id) }

  context 'with no grouping' do
    it 'returns aggregated quantities and nil grouped_cards' do
      result = described_class.call(cards: cards, user: user, grouping: 'none')
      expect(result[:aggregated_quantities]).to be_a(Hash)
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
end
