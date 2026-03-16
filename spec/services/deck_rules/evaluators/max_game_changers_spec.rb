require 'rails_helper'

RSpec.describe DeckRules::Evaluators::MaxGameChangers do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:boxset) { create(:boxset) }
  let(:bracket) { create(:bracket, level: 1) }
  let(:rule) { create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', value: 2, name: 'Max 2 GC') }

  describe '#evaluate' do
    context 'with no game changers' do
      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
        expect(result[:limit]).to eq(2)
        expect(result[:offending_cards]).to be_empty
      end
    end

    context 'with game changers within limit' do
      before do
        2.times do
          oracle_id = SecureRandom.uuid
          create(:game_changer, oracle_id: oracle_id, card_name: "GC #{oracle_id[0..5]}")
          card = create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id)
          create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
        end
      end

      it 'passes' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(2)
      end
    end

    context 'with game changers exceeding limit' do
      before do
        3.times do |i|
          oracle_id = SecureRandom.uuid
          create(:game_changer, oracle_id: oracle_id, card_name: "GC #{i}")
          card = create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id, name: "Game Changer #{i}")
          create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
        end
      end

      it 'fails with offending cards' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be false
        expect(result[:actual]).to eq(3)
        expect(result[:offending_cards].size).to eq(3)
      end
    end

    context 'when game changer is a commander' do
      before do
        oracle_id = SecureRandom.uuid
        create(:game_changer, oracle_id: oracle_id, card_name: 'Thassa')
        card = create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1, board_type: 'commander')
      end

      it 'excludes commanders' do
        result = described_class.new(rule: rule, deck: deck).evaluate

        expect(result[:passed]).to be true
        expect(result[:actual]).to eq(0)
      end
    end

    it 'shares context between evaluations' do
      oracle_id = SecureRandom.uuid
      create(:game_changer, oracle_id: oracle_id, card_name: 'Test GC')

      context = {}
      described_class.new(rule: rule, deck: deck, context: context).evaluate

      expect(context).to have_key(:gc_oracle_ids)
      expect(context).to have_key(:game_changer_count)
    end
  end

  describe '#violation_message' do
    it 'returns a human-readable message' do
      evaluator = described_class.new(rule: rule, deck: deck)
      evaluator.evaluate

      expect(evaluator.violation_message).to match(/Deck has \d+ game changers \(limit: 2\)/)
    end
  end
end
