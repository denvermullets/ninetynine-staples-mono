require 'rails_helper'

RSpec.describe DeckBuilder::LoadCombos, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck', combos_checked_at: 1.hour.ago) }

  subject { described_class.call(deck: deck) }

  context 'with no combos' do
    it 'returns empty maps' do
      result = subject
      expect(result[:combo_card_oracle_ids]).to be_empty
      expect(result[:combos_by_oracle_id]).to be_empty
    end

    it 'returns checked_at' do
      result = subject
      expect(result[:checked_at]).to be_present
    end
  end

  context 'with included and almost_included combos' do
    let(:combo1) { Combo.create!(spellbook_id: 'combo-1') }
    let(:combo2) { Combo.create!(spellbook_id: 'combo-2') }

    before do
      combo1.combo_cards.create!(card_name: 'Card A', oracle_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      combo1.combo_cards.create!(card_name: 'Card B', oracle_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
      combo2.combo_cards.create!(card_name: 'Card A', oracle_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      combo2.combo_cards.create!(card_name: 'Card C', oracle_id: 'cccccccc-cccc-cccc-cccc-cccccccccccc')

      DeckCombo.create!(collection: deck, combo: combo1, combo_type: 'included')
      DeckCombo.create!(collection: deck, combo: combo2, combo_type: 'almost_included')
    end

    it 'maps oracle_ids to combo types' do
      result = subject
      expect(result[:combo_card_oracle_ids]['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa']).to eq(:included)
      expect(result[:combo_card_oracle_ids]['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb']).to eq(:included)
      expect(result[:combo_card_oracle_ids]['cccccccc-cccc-cccc-cccc-cccccccccccc']).to eq(:almost_included)
    end

    it 'gives included priority over almost_included' do
      result = subject
      # oracle-a appears in both combo1 (included) and combo2 (almost_included)
      expect(result[:combo_card_oracle_ids]['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa']).to eq(:included)
    end

    it 'maps oracle_ids to deck_combos' do
      result = subject
      expect(result[:combos_by_oracle_id]['aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'].size).to eq(2)
      expect(result[:combos_by_oracle_id]['bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'].size).to eq(1)
    end
  end

  describe '.combos_for_card' do
    let(:combo) { Combo.create!(spellbook_id: 'combo-1') }

    before do
      combo.combo_cards.create!(card_name: 'Card A', oracle_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      combo.combo_cards.create!(card_name: 'Card B', oracle_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb')
      DeckCombo.create!(collection: deck, combo: combo, combo_type: 'included')
    end

    it 'returns deck_combos for the given oracle_id' do
      result = described_class.combos_for_card(deck: deck, oracle_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa')
      expect(result.size).to eq(1)
      expect(result.first.combo).to eq(combo)
    end

    it 'returns empty when oracle_id has no combos' do
      result = described_class.combos_for_card(deck: deck, oracle_id: 'nonexistent')
      expect(result).to be_empty
    end
  end
end
