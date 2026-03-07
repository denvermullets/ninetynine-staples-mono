require 'rails_helper'

RSpec.describe Collections::GroupCards, type: :service do
  let!(:rare_card) { create(:magic_card, rarity: 'rare') }
  let!(:common_card) { create(:magic_card, rarity: 'common') }

  let(:cards) { MagicCard.where(id: [rare_card.id, common_card.id]) }

  context 'with no grouping' do
    it 'returns all cards in one group' do
      result = described_class.call(cards: cards, grouping: 'none')
      expect(result.keys).to eq(['All Cards'])
      expect(result['All Cards'].size).to eq(2)
    end
  end

  context 'grouping by rarity' do
    it 'groups cards by rarity' do
      result = described_class.call(cards: cards, grouping: 'rarity')
      expect(result.keys).to include('Rare', 'Common')
    end

    it 'sorts groups in rarity order' do
      result = described_class.call(cards: cards, grouping: 'rarity')
      keys = result.keys
      expect(keys.index('Rare')).to be < keys.index('Common')
    end
  end

  context 'with empty cards' do
    it 'returns empty hash' do
      result = described_class.call(cards: [], grouping: 'rarity')
      expect(result).to eq({})
    end
  end

  context 'with invalid grouping' do
    it 'defaults to none' do
      result = described_class.call(cards: cards, grouping: 'invalid')
      expect(result.keys).to eq(['All Cards'])
    end
  end
end
