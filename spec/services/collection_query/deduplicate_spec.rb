require 'rails_helper'

RSpec.describe CollectionQuery::Deduplicate, type: :service do
  let!(:card_a) { create(:magic_card, name: 'Lightning Bolt', edhrec_rank: 10) }
  let!(:card_b) { create(:magic_card, name: 'Lightning Bolt', edhrec_rank: 5) }
  let!(:card_c) { create(:magic_card, name: 'Dark Ritual', edhrec_rank: 20) }

  let(:cards) { MagicCard.where(id: [card_a.id, card_b.id, card_c.id]) }

  context 'deduplicating by name' do
    it 'returns one card per unique name' do
      result = described_class.call(cards: cards, column: :name, prefer_by: :edhrec_rank)
      expect(result.map(&:name).uniq.count).to eq(2)
    end
  end

  context 'with invalid column' do
    it 'returns the original cards' do
      result = described_class.call(cards: cards, column: :invalid_column)
      expect(result).to eq(cards)
    end
  end

  context 'with DESC prefer direction' do
    it 'prefers higher values' do
      result = described_class.call(
        cards: cards, column: :name, prefer_by: :edhrec_rank, prefer_direction: :desc
      )
      bolt = result.find { |c| c.name == 'Lightning Bolt' }
      expect(bolt.edhrec_rank).to eq(10)
    end
  end
end
