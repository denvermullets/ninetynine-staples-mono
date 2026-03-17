module DeckRules
  module Evaluators
    class MinCardsInInfiniteCombo < Base
      def evaluate
        violating = violating_combos
        offending = violating.flat_map { |dc| dc.combo.combo_cards.map(&:card_name) }.uniq

        {
          passed: violating.empty?,
          actual: violating.size,
          limit: @rule.value,
          rule_name: @rule.name,
          rule_type: @rule.rule_type,
          offending_cards: offending
        }
      end

      def violation_message
        count = violating_combos.size
        "#{count} infinite combo(s) with fewer than #{@rule.value} cards"
      end

      private

      def violating_combos
        @context[:violating_infinite_combos] ||=
          infinite_combos.select { |dc| dc.combo.combo_cards.size < @rule.value }
      end

      def infinite_combos
        @context[:infinite_combos] ||=
          @deck.deck_combos
               .included_combos
               .joins(:combo)
               .where("combos.results ILIKE '%Infinite%'")
               .includes(combo: :combo_cards)
               .to_a
      end
    end
  end
end
