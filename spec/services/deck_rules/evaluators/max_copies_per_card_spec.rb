require 'rails_helper'

RSpec.describe DeckRules::Evaluators::MaxCopiesPerCard do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:boxset) { create(:boxset) }
  let(:bracket) { create(:bracket, level: 1) }
  let(:rule) { create(:deck_rule, bracket: bracket, rule_type: 'max_copies_per_card', value: 1, name: 'Max 1 Copy') }

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
        card = create(:magic_card, boxset: boxset, name: 'Lightning Bolt')
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
      end

      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(1)
      end
    end

    context 'with cards exceeding limit' do
      before do
        card = create(:magic_card, boxset: boxset, name: 'Lightning Bolt')
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 3)
      end

      it 'fails with offending cards' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be false
        expect(result[:actual]).to eq(3)
        expect(result[:offending_cards]).to include(match(/Lightning Bolt/))
      end
    end

    context 'with basic lands' do
      before do
        card = create(:magic_card, boxset: boxset, name: 'Plains')
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 10)
      end

      it 'excludes basic lands' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end

    context 'with commanders' do
      before do
        card = create(:magic_card, boxset: boxset, name: 'Thassa')
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1, board_type: 'commander')
      end

      it 'excludes commanders' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end
  end
end
