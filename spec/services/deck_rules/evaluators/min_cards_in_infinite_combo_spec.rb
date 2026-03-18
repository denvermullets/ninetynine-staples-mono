require 'rails_helper'

RSpec.describe DeckRules::Evaluators::MinCardsInInfiniteCombo do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:bracket) { create(:bracket, level: 1) }
  let(:rule) do
    create(:deck_rule, bracket: bracket, rule_type: 'min_cards_in_infinite_combo',
                       value: 3, name: 'No 2-card infinites')
  end

  def create_combo(card_count:, results: 'Infinite mana', combo_type: 'included')
    combo = Combo.create!(spellbook_id: SecureRandom.uuid, results: results)
    card_count.times do |i|
      combo.combo_cards.create!(card_name: "Card #{combo.id}-#{i}", oracle_id: SecureRandom.uuid)
    end
    deck.deck_combos.create!(combo: combo, combo_type: combo_type)
    combo
  end

  describe '#evaluate' do
    context 'with no combos' do
      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
        expect(result[:offending_cards]).to be_empty
      end
    end

    context 'with a 2-card infinite combo (below minimum)' do
      before { create_combo(card_count: 2) }

      it 'fails' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be false
        expect(result[:actual]).to eq(1)
        expect(result[:offending_cards].size).to eq(2)
      end
    end

    context 'with a 3-card infinite combo (meets minimum)' do
      before { create_combo(card_count: 3) }

      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end

    context 'with a non-infinite 2-card combo' do
      before { create_combo(card_count: 2, results: 'Draw 2 cards') }

      it 'passes because the combo is not infinite' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end

    context 'with an almost_included 2-card infinite combo' do
      before { create_combo(card_count: 2, combo_type: 'almost_included') }

      it 'passes because the combo is not fully included' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end

    context 'with a mix of violating and non-violating combos' do
      before do
        create_combo(card_count: 2, results: 'Infinite mana')
        create_combo(card_count: 2, results: 'Infinite damage')
        create_combo(card_count: 4, results: 'Infinite tokens')
      end

      it 'counts only combos below the minimum' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be false
        expect(result[:actual]).to eq(2)
      end
    end
  end

  describe '#violation_message' do
    before { create_combo(card_count: 2) }

    it 'returns a human-readable message' do
      evaluator = described_class.new(rule: rule, deck: deck)
      evaluator.evaluate

      expect(evaluator.violation_message).to eq('Deck has 1 infinite combo that use fewer than 3 cards')
    end
  end
end
