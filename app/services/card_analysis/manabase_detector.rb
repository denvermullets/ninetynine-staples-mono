module CardAnalysis
  class ManabaseDetector < Service
    def initialize(text:, card_type:, results:)
      @text = text
      @card_type = card_type
      @results = results
    end

    def call
      return unless @card_type.include?('land')

      detect_fetch_land
      detect_shock_land
      detect_pain_land
      detect_check_land
      detect_bounce_land
      detect_filter_land
      detect_mana_confluence
      detect_utility_land
      detect_tri_land
      detect_generic_dual_land
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

    def detect_fetch_land
      fetch_re = /search your library for .*(land card|plains|island|swamp|mountain|forest)/
      return unless match?(fetch_re) && match?(/put .*(onto the battlefield|into play)/)

      add(role: 'manabase', effect: 'fetch_land', confidence: 0.95)
    end

    def detect_shock_land
      return unless (match?(/pay 2 life/) && match?(/enters .* tapped/)) ||
                    match?(/you may pay 2 life.*if you don't.*enters.*tapped/)

      add(role: 'manabase', effect: 'shock_land', confidence: 0.95)
    end

    def detect_pain_land
      return unless match?(/deals 1 damage to you/) && match?(/\{t\}: add \{[wubrg]\}/i)

      add(role: 'manabase', effect: 'pain_land', confidence: 0.9)
    end

    def detect_check_land
      check_re = /enters .* tapped unless you control (a|an) (plains|island|swamp|mountain|forest)/i
      return unless match?(check_re)

      add(role: 'manabase', effect: 'check_land', confidence: 0.9)
    end

    def detect_bounce_land
      return unless match?(/enters .* tapped/) && match?(/return a land you control/)

      add(role: 'manabase', effect: 'bounce_land', confidence: 0.9)
    end

    def detect_filter_land
      return unless match?(/\{1\}, \{t\}: add \{[wubrg]\}\{[wubrg]\}/i)

      add(role: 'manabase', effect: 'filter_land', confidence: 0.9)
    end

    def detect_mana_confluence
      return unless match?(/add one mana of any color/i) &&
                    match?(/deals? \d+ damage to you|pay 1 life|lose 1 life/)

      add(role: 'manabase', effect: 'mana_confluence', confidence: 0.9)
    end

    def detect_utility_land
      return unless match?(/\{t\}.*:/) &&
                    (match?(/draw|destroy|exile|create|counter|return|sacrifice|deals? \d+ damage/) ||
                     match?(/put .* counter/))

      add(role: 'manabase', effect: 'utility_land', confidence: 0.8)
    end

    def detect_tri_land
      return unless match?(/\{t\}: add \{[wubrg]\}, \{[wubrg]\}, or \{[wubrg]\}/i)

      add(role: 'manabase', effect: 'tri_land', confidence: 0.9)
    end

    def detect_generic_dual_land
      mana_colors = @text.scan(/\{([wubrg])\}/i).flatten.uniq
      return unless @text.match?(/add /i) && mana_colors.size >= 2

      add(role: 'manabase', effect: 'dual_land', confidence: 0.7)
    end
  end
end
