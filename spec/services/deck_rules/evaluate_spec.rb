require 'rails_helper'

RSpec.describe DeckRules::Evaluate do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:boxset) { create(:boxset) }

  describe '#call' do
    context 'with no rules' do
      it 'returns empty violations' do
        result = described_class.call(deck: deck)

        expect(result[:violations]).to be_empty
        expect(result[:evaluated_at]).to be_present
      end
    end

    context 'with bracket-specific rules' do
      let!(:bracket) { create(:bracket, level: 2, name: 'Casual') }
      let!(:rule) do
        create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', value: 0, name: 'No GC')
      end

      before { deck.update!(bracket_level: 2) }

      context 'when deck passes all rules' do
        it 'returns no violations' do
          result = described_class.call(deck: deck)

          expect(result[:violations]).to be_empty
          expect(result[:bracket]).to eq(bracket)
        end
      end

      context 'when deck violates a rule' do
        before do
          oracle_id = SecureRandom.uuid
          create(:game_changer, oracle_id: oracle_id, card_name: 'Sol Ring')
          card = create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id, name: 'Sol Ring')
          create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
        end

        it 'returns violations' do
          result = described_class.call(deck: deck)

          expect(result[:violations].size).to eq(1)
          violation = result[:violations].first
          expect(violation[:rule_name]).to eq('No GC')
          expect(violation[:rule_type]).to eq('max_game_changers')
          expect(violation[:message]).to match(/game changers/)
          expect(violation[:offending_cards]).to include('Sol Ring')
        end
      end
    end

    context 'with global rules' do
      let!(:global_rule) do
        create(:deck_rule, bracket: nil, rule_type: 'max_deck_size', value: 100, name: 'Global Max Size')
      end

      before do
        card = create(:magic_card, boxset: boxset)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 101)
      end

      it 'evaluates global rules' do
        result = described_class.call(deck: deck)

        expect(result[:violations].size).to eq(1)
        expect(result[:violations].first[:rule_name]).to eq('Global Max Size')
      end
    end

    context 'bracket rule overrides global rule' do
      let!(:bracket) { create(:bracket, level: 1, name: 'Precon') }
      let!(:global_rule) do
        create(:deck_rule, bracket: nil, rule_type: 'max_deck_size', value: 50, name: 'Global Strict')
      end
      let!(:bracket_rule) do
        create(:deck_rule, bracket: bracket, rule_type: 'max_deck_size', value: 200, name: 'B1 Lenient')
      end

      before do
        deck.update!(bracket_level: 1)
        card = create(:magic_card, boxset: boxset)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 100)
      end

      it 'uses bracket rule instead of global' do
        result = described_class.call(deck: deck)

        expect(result[:violations]).to be_empty
      end
    end

    context 'applies_to filtering' do
      let!(:bracket) { create(:bracket, level: 1) }
      let!(:deck_only_rule) do
        create(:deck_rule, bracket: bracket, rule_type: 'max_deck_size', value: 10,
                           name: 'Deck Only', applies_to: 'deck')
      end

      before do
        deck.update!(bracket_level: 1)
        card = create(:magic_card, boxset: boxset)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 50)
      end

      it 'skips rules that do not apply to the deck type' do
        result = described_class.call(deck: deck)

        expect(result[:violations]).to be_empty
      end
    end

    context 'with explicit bracket argument' do
      let!(:bracket) { create(:bracket, level: 3, name: 'Optimized') }
      let!(:rule) do
        create(:deck_rule, bracket: bracket, rule_type: 'max_game_changers', value: 0, name: 'No GC B3')
      end

      let(:oracle_id) { SecureRandom.uuid }

      before do
        create(:game_changer, oracle_id: oracle_id, card_name: 'Sol Ring')
        card = create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id)
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
      end

      it 'uses the provided bracket' do
        result = described_class.call(deck: deck, bracket: bracket)

        expect(result[:bracket]).to eq(bracket)
        expect(result[:violations].size).to eq(1)
      end
    end
  end
end
