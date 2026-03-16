require 'rails_helper'

RSpec.describe DeckRules::Evaluators::MaxDeckSize do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:boxset) { create(:boxset) }
  let(:bracket) { create(:bracket, level: 1) }
  let(:rule) { create(:deck_rule, bracket: bracket, rule_type: 'max_deck_size', value: 100, name: 'Max 100 Cards') }

  describe '#evaluate' do
    context 'with no cards' do
      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end

    context 'with cards within limit' do
      before do
        card = create(:magic_card, boxset: boxset)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 50)
      end

      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(50)
      end
    end

    context 'with cards exceeding limit' do
      before do
        card = create(:magic_card, boxset: boxset)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 101)
      end

      it 'fails' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be false
        expect(result[:actual]).to eq(101)
      end
    end

    context 'counts all quantity types' do
      before do
        card = create(:magic_card, boxset: boxset)
        create(:collection_magic_card, collection: deck, magic_card: card,
                                       quantity: 30, foil_quantity: 30, proxy_quantity: 30, proxy_foil_quantity: 30)
      end

      it 'sums all quantity fields' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be false
        expect(result[:actual]).to eq(120)
      end
    end
  end

  describe '#violation_message' do
    before do
      card = create(:magic_card, boxset: boxset)
      create(:collection_magic_card, collection: deck, magic_card: card, quantity: 101)
    end

    it 'returns a human-readable message' do
      evaluator = described_class.new(rule: rule, deck: deck)
      evaluator.evaluate

      expect(evaluator.violation_message).to eq('Deck has 101 cards (limit: 100)')
    end
  end
end
