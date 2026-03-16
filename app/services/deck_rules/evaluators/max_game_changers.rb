module DeckRules
  module Evaluators
    class MaxGameChangers < Base
      def evaluate
        count = game_changer_count
        offending = count > @rule.value ? offending_card_names : []

        {
          passed: count <= @rule.value,
          actual: count,
          limit: @rule.value,
          rule_name: @rule.name,
          rule_type: @rule.rule_type,
          offending_cards: offending
        }
      end

      def violation_message
        "Deck has #{game_changer_count} game changers (limit: #{@rule.value})"
      end

      private

      def gc_oracle_ids
        @context[:gc_oracle_ids] ||= GameChanger.pluck(:oracle_id)
      end

      def game_changer_count
        @context[:game_changer_count] ||= compute_game_changer_count
      end

      def compute_game_changer_count
        return 0 if gc_oracle_ids.empty?

        deck_oracle_ids = deck_cards
                          .where.not(collection_magic_cards: { board_type: 'commander' })
                          .pluck('magic_cards.scryfall_oracle_id')

        (deck_oracle_ids & gc_oracle_ids).size
      end

      def offending_card_names
        return [] if gc_oracle_ids.empty?

        deck_cards
          .where.not(collection_magic_cards: { board_type: 'commander' })
          .where(magic_cards: { scryfall_oracle_id: gc_oracle_ids })
          .pluck('magic_cards.name')
          .uniq
      end
    end
  end
end
