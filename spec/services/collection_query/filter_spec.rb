require 'rails_helper'

RSpec.describe CollectionQuery::Filter, type: :service do
  let(:boxset) { create(:boxset, code: 'TST') }
  let!(:rare_card) { create(:magic_card, rarity: 'rare', boxset: boxset) }
  let!(:common_card) { create(:magic_card, rarity: 'common', boxset: create(:boxset)) }

  let(:cards) { MagicCard.all }

  context 'when filtering by rarity' do
    it 'returns only matching rarities' do
      result = described_class.call(cards: cards, rarities: ['rare'])
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end
  end

  context 'when filtering by boxset code' do
    it 'returns only cards from that boxset' do
      result = described_class.call(cards: cards, code: 'TST')
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end
  end

  context 'when filtering by price change range' do
    before do
      rare_card.update_column(:price_change_weekly_normal, 15.0)
      common_card.update_column(:price_change_weekly_normal, 2.0)
    end

    it 'filters cards within the price change range' do
      result = described_class.call(cards: cards, price_change_min: 10.0, price_change_max: 20.0)
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end
  end

  context 'with no filters applied' do
    it 'returns all cards' do
      result = described_class.call(cards: cards)
      expect(result.count).to eq(cards.count)
    end
  end

  context 'when parsing from params' do
    it 'parses rarity from params' do
      result = described_class.call(
        cards: cards,
        params: { rarity: ['rare'] }
      )
      expect(result).to include(rare_card)
      expect(result).not_to include(common_card)
    end

    it 'parses price change range from params' do
      rare_card.update_column(:price_change_weekly_normal, 15.0)
      result = described_class.call(
        cards: cards,
        params: { price_change_range: '10.0,20.0' }
      )
      expect(result).to include(rare_card)
    end
  end
end
