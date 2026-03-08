require 'rails_helper'

RSpec.describe CollectionQuery::Search, type: :service do
  let(:boxset) { create(:boxset) }
  let!(:card_a) { create(:magic_card, name: 'Lightning Bolt', boxset: boxset) }
  let!(:card_b) { create(:magic_card, name: 'Lightning Helix', boxset: create(:boxset)) }
  let!(:card_c) { create(:magic_card, name: 'Dark Ritual', boxset: create(:boxset)) }

  let(:cards) { MagicCard.all }

  context 'with a search term' do
    it 'filters cards by name' do
      result = described_class.call(cards: cards, search_term: 'Lightning')
      expect(result).to include(card_a, card_b)
      expect(result).not_to include(card_c)
    end
  end

  context 'with a search term and boxset_id' do
    it 'filters by name and boxset' do
      result = described_class.call(cards: cards, search_term: 'Lightning', boxset_id: boxset.id)
      expect(result).to include(card_a)
      expect(result).not_to include(card_b)
    end
  end

  context 'without a search term' do
    it 'returns the original cards' do
      result = described_class.call(cards: cards, search_term: nil)
      expect(result).to eq(cards)
    end

    it 'returns cards when search term is blank' do
      result = described_class.call(cards: cards, search_term: '')
      expect(result).to eq(cards)
    end
  end
end
