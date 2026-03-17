module DeckRules
  module Evaluators
    class Base
      BASIC_LAND_NAMES = %w[Plains Island Swamp Mountain Forest Wastes].freeze

      EVALUATOR_MAP = {
        'max_game_changers' => 'DeckRules::Evaluators::MaxGameChangers',
        'max_copies_per_card' => 'DeckRules::Evaluators::MaxCopiesPerCard',
        'max_deck_size' => 'DeckRules::Evaluators::MaxDeckSize',
        'min_cards_in_infinite_combo' => 'DeckRules::Evaluators::MinCardsInInfiniteCombo'
      }.freeze

      def self.for(rule_type)
        class_name = EVALUATOR_MAP[rule_type]
        raise ArgumentError, "Unknown rule type: #{rule_type}" unless class_name

        class_name.constantize
      end

      def initialize(rule:, deck:, context: {})
        @rule = rule
        @deck = deck
        @context = context
      end

      def evaluate
        raise NotImplementedError
      end

      def violation_message
        raise NotImplementedError
      end

      private

      def deck_cards
        @deck.collection_magic_cards.joins(:magic_card)
      end
    end
  end
end
