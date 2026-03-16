require 'rails_helper'

RSpec.describe DeckRules::DetectBracket do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'commander_deck') }
  let(:boxset) { create(:boxset) }

  describe '#call' do
    context 'when no brackets exist' do
      it 'returns nil detected bracket' do
        result = described_class.call(deck: deck)

        expect(result[:detected_bracket]).to be_nil
        expect(result[:details]).to be_empty
      end
    end

    context 'with brackets and game changer rules' do
      let!(:bracket_one) { create(:bracket, level: 1, name: 'Precon') }
      let!(:bracket_two) { create(:bracket, level: 2, name: 'Casual') }
      let!(:bracket_three) { create(:bracket, level: 3, name: 'Optimized') }
      let!(:bracket_four) { create(:bracket, level: 4, name: 'High Power') }

      let!(:rule_b_one) do
        create(:deck_rule, bracket: bracket_one, rule_type: 'max_game_changers', value: 0, name: 'B1 GC')
      end
      let!(:rule_b_two) do
        create(:deck_rule, bracket: bracket_two, rule_type: 'max_game_changers', value: 0, name: 'B2 GC')
      end
      let!(:rule_b_three) do
        create(:deck_rule, bracket: bracket_three, rule_type: 'max_game_changers', value: 3, name: 'B3 GC')
      end
      let!(:rule_b_four) do
        create(:deck_rule, bracket: bracket_four, rule_type: 'max_game_changers', value: 9999, name: 'B4 GC')
      end

      context 'when deck has no game changers' do
        it 'detects bracket 1' do
          result = described_class.call(deck: deck)

          expect(result[:detected_bracket]).to eq(bracket_one)
          expect(result[:game_changer_count]).to eq(0)
        end
      end

      context 'when deck has 1 game changer' do
        let(:oracle_id) { SecureRandom.uuid }
        let!(:gc) { create(:game_changer, oracle_id: oracle_id, card_name: 'Sol Ring') }
        let(:card) { create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id) }

        before do
          create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
        end

        it 'detects bracket 3 (skips B1 and B2 which allow 0)' do
          result = described_class.call(deck: deck)

          expect(result[:detected_bracket]).to eq(bracket_three)
          expect(result[:game_changer_count]).to eq(1)
        end
      end

      context 'when deck has 4 game changers' do
        before do
          4.times do
            oracle_id = SecureRandom.uuid
            create(:game_changer, oracle_id: oracle_id, card_name: "GC #{oracle_id[0..5]}")
            card = create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id)
            create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
          end
        end

        it 'detects bracket 4 (exceeds B3 limit of 3)' do
          result = described_class.call(deck: deck)

          expect(result[:detected_bracket]).to eq(bracket_four)
          expect(result[:game_changer_count]).to eq(4)
        end
      end

      context 'when game changer is a commander' do
        let(:oracle_id) { SecureRandom.uuid }
        let!(:gc) { create(:game_changer, oracle_id: oracle_id, card_name: 'Thassa') }
        let(:card) { create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id) }

        before do
          create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1, board_type: 'commander')
        end

        it 'excludes commanders from game changer count' do
          result = described_class.call(deck: deck)

          expect(result[:game_changer_count]).to eq(0)
          expect(result[:detected_bracket]).to eq(bracket_one)
        end
      end
    end

    context 'with disabled brackets' do
      let!(:bracket_one) { create(:bracket, level: 1, name: 'Precon', enabled: false) }
      let!(:bracket_two) { create(:bracket, level: 2, name: 'Casual', enabled: true) }

      let!(:rule_b_two) do
        create(:deck_rule, bracket: bracket_two, rule_type: 'max_game_changers', value: 0, name: 'B2 GC')
      end

      it 'only considers enabled brackets' do
        result = described_class.call(deck: deck)

        expect(result[:detected_bracket]).to eq(bracket_two)
      end
    end

    context 'with disabled rules' do
      let!(:bracket_one) { create(:bracket, level: 1, name: 'Precon') }
      let!(:rule) do
        create(:deck_rule, bracket: bracket_one, rule_type: 'max_game_changers', value: 0,
                           name: 'B1 GC', enabled: false)
      end

      let(:oracle_id) { SecureRandom.uuid }
      let!(:gc) { create(:game_changer, oracle_id: oracle_id, card_name: 'Sol Ring') }
      let(:card) { create(:magic_card, boxset: boxset, scryfall_oracle_id: oracle_id) }

      before do
        create(:collection_magic_card, collection: deck, magic_card: card, quantity: 1)
      end

      it 'ignores disabled rules (bracket passes with no active rules)' do
        result = described_class.call(deck: deck)

        expect(result[:detected_bracket]).to eq(bracket_one)
      end
    end
  end
end
