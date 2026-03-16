module DeckRules
  module Evaluators
    class MaxDeckSize < Base
      def evaluate
        total = deck_card_count

        {
          passed: total <= @rule.value,
          actual: total,
          limit: @rule.value,
          rule_name: @rule.name,
          rule_type: @rule.rule_type,
          offending_cards: []
        }
      end

      def violation_message
        "Deck has #{deck_card_count} cards (limit: #{@rule.value})"
      end

      private

      def deck_card_count
        @context[:deck_card_count] ||=
          @deck.collection_magic_cards.sum(:quantity) +
          @deck.collection_magic_cards.sum(:foil_quantity) +
          @deck.collection_magic_cards.sum(:proxy_quantity) +
          @deck.collection_magic_cards.sum(:proxy_foil_quantity)
      end
    end
  end
end
