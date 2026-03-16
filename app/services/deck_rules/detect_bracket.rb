module DeckRules
  class DetectBracket < Service
    def initialize(deck:)
      @deck = deck
      @context = {}
      @details = []
    end

    def call
      brackets = Bracket.enabled.ordered.includes(:deck_rules)
      return { detected_bracket: nil, details: [] } if brackets.empty?

      detected = brackets.detect { |bracket| bracket_passes?(bracket) }

      {
        detected_bracket: detected,
        game_changer_count: @context[:game_changer_count] || 0,
        details: @details
      }
    end

    private

    def bracket_passes?(bracket)
      rules = bracket.deck_rules.select(&:enabled)
      return true if rules.empty?

      rules.all? do |rule|
        evaluator = Evaluators::Base.for(rule.rule_type).new(rule: rule, deck: @deck, context: @context)
        result = evaluator.evaluate
        @details << { bracket_level: bracket.level, rule: rule.name, passed: result[:passed],
                      actual: result[:actual], limit: rule.value }
        result[:passed]
      end
    end
  end
end
