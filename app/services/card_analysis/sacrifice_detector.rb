module CardAnalysis
  class SacrificeDetector < Service
    def initialize(text:, results:)
      @text = text
      @results = results
    end

    def call
      detect_broad_outlet
      detect_additional_cost
      detect_optional_sacrifice
      detect_sacrificed_payoff
    end

    private

    def match?(pattern)
      @text.match?(pattern)
    end

    def add(role:, effect:, confidence:)
      key = [role, effect]
      existing = @results[key]
      return unless existing.nil? || confidence > existing[:confidence]

      @results[key] = { role: role, effect: effect, confidence: confidence, source: 'pattern' }
    end

    # Broad sac outlet: sacrifice a/an/another TYPE (without requiring colon)
    def detect_broad_outlet
      sac_re = /sacrifice (a|an|another|one|two|three) (creature|permanent|artifact|enchantment|token)/
      return unless match?(sac_re)

      add(role: 'sacrifice', effect: 'sacrifice_outlet', confidence: 0.85)
    end

    # "As an additional cost" sacrifice (Village Rites, Deadly Dispute)
    def detect_additional_cost
      return unless match?(/as an additional cost.*sacrifice/)

      add(role: 'sacrifice', effect: 'sacrifice_outlet', confidence: 0.85)
    end

    # "you may sacrifice" (optional sacrifice for value)
    def detect_optional_sacrifice
      return unless match?(/you may sacrifice (a|an|another)/)

      add(role: 'sacrifice', effect: 'sacrifice_outlet', confidence: 0.8)
    end

    # Broader aristocrat payoff: whenever something is sacrificed
    def detect_sacrificed_payoff
      return unless match?(/whenever .* (is|are) sacrificed/)

      add(role: 'sacrifice', effect: 'aristocrat_payoff', confidence: 0.85)
    end
  end
end
