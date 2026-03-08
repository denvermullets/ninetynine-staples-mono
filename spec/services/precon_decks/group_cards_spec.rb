require 'rails_helper'

RSpec.describe PreconDecks::GroupCards, type: :service do
  let(:boxset) { create(:boxset) }
  let(:creature_card) { create(:magic_card, card_type: 'Creature', mana_value: 3, rarity: 'rare', boxset: boxset) }
  let(:instant_card) {
    create(:magic_card, card_type: 'Instant', mana_value: 1, rarity: 'common', boxset: create(:boxset))
  }

  let(:precon_deck) { PreconDeck.create!(code: 'TST', file_name: 'test_deck', name: 'Test Deck') }

  let!(:commander_pdc) do
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: creature_card,
      board_type: 'commander', quantity: 1
    )
  end

  let!(:mainboard_pdc) do
    PreconDeckCard.create!(
      precon_deck: precon_deck, magic_card: instant_card,
      board_type: 'mainBoard', quantity: 4
    )
  end

  let(:cards) { precon_deck.precon_deck_cards.includes(magic_card: :boxset) }

  context 'grouping by type' do
    it 'separates commanders into their own section' do
      result = described_class.call(cards: cards, grouping: 'type')
      expect(result.keys.first).to eq('Commander')
    end

    it 'groups main board cards by type' do
      result = described_class.call(cards: cards, grouping: 'type')
      expect(result.keys).to include('Instant')
    end
  end

  context 'grouping by zone' do
    it 'groups by board type' do
      result = described_class.call(cards: cards, grouping: 'zone')
      expect(result.keys).to include('Commander', 'Main Board')
    end
  end

  context 'grouping by none' do
    it 'separates commanders and puts rest in All Cards' do
      result = described_class.call(cards: cards, grouping: 'none')
      expect(result.keys).to include('Commander', 'All Cards')
    end
  end

  context 'with empty cards' do
    it 'returns empty hash' do
      result = described_class.call(cards: [], grouping: 'type')
      expect(result).to eq({})
    end
  end
end
