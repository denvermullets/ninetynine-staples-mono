module DeckRules
  class Evaluate < Service
    def initialize(deck:, bracket: nil)
      @deck = deck
      @bracket = bracket
    end

    def call
      target_bracket = resolve_bracket
      rules = resolve_rules(target_bracket)
      context = {}

      violations = rules.filter_map do |rule|
        evaluator = Evaluators::Base.for(rule.rule_type).new(rule: rule, deck: @deck, context: context)
        result = evaluator.evaluate
        next if result[:passed]

        {
          rule_name: result[:rule_name],
          rule_type: result[:rule_type],
          message: evaluator.violation_message,
          offending_cards: result[:offending_cards]
        }
      end

      {
        violations: violations,
        bracket: target_bracket,
        evaluated_at: Time.current
      }
    end

    private

    def resolve_bracket
      return @bracket if @bracket

      if @deck.respond_to?(:bracket_level) && @deck.bracket_level.present?
        Bracket.find_by(level: @deck.bracket_level)
      else
        DetectBracket.call(deck: @deck)[:detected_bracket]
      end
    end

    def resolve_rules(target_bracket)
      deck_type = @deck.collection_type
      bracket_rules = if target_bracket
                        DeckRule.enabled.for_bracket(target_bracket).applicable_to(deck_type)
                      else
                        DeckRule.none
                      end
      global_rules = DeckRule.enabled.global.applicable_to(deck_type)

      bracket_rule_types = bracket_rules.pluck(:rule_type)
      filtered_globals = global_rules.where.not(rule_type: bracket_rule_types)

      (bracket_rules.to_a + filtered_globals.to_a)
    end
  end
end
