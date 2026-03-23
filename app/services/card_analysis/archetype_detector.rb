module CardAnalysis
  class ArchetypeDetector < Service
    PATTERNS = [
      # Stax / Tax
      { pattern: /spells? (your opponents? cast |they cast )?costs? \{?\d?\}? ?more/,
        role: 'stax', effect: 'tax_effect', confidence: 0.9 },
      { pattern: /whenever an opponent casts.*unless .* pays?/,
        role: 'stax', effect: 'tax_effect', confidence: 0.9 },
      { pattern: /can't cast more than (one|1) spell(s)? each turn/,
        role: 'stax', effect: 'rule_of_law', confidence: 0.95 },
      { pattern: /each player can't cast more than/,
        role: 'stax', effect: 'rule_of_law', confidence: 0.95 },
      { pattern: /(don't|doesn't) untap during/,
        role: 'stax', effect: 'resource_denial', confidence: 0.9 },
      { pattern: /players? can't (search|draw more|cast .* from|play lands? from)/,
        role: 'stax', effect: 'static_stax', confidence: 0.9 },
      { pattern: /opponents? can't (cast|activate|play|search)/,
        role: 'stax', effect: 'static_stax', confidence: 0.9 },
      { pattern: /nonland permanents .* opponents? control enter .* tapped/,
        role: 'stax', effect: 'resource_denial', confidence: 0.85 },

      # Blink / Flicker
      { pattern: /exile target .* (creature|permanent).*return (it|that card|that permanent) to the battlefield/,
        role: 'blink', effect: 'flicker', confidence: 0.95 },
      { pattern: /exile .*(creature|permanent).*return .* to the battlefield (at the beginning|under)/,
        role: 'blink', effect: 'flicker', confidence: 0.9 },
      { pattern: /whenever (a|another) (creature|permanent|nontoken creature) enters the battlefield under your/,
        role: 'blink', effect: 'etb_payoff', confidence: 0.85 },
      { pattern: /when .* enters the battlefield.*(?:draw|destroy|exile|create|return|search|deal|gain)/,
        role: 'blink', effect: 'etb_payoff', confidence: 0.5 },

      # Copy / Clone
      { pattern: /(enters?|enter) .* as a copy of/,
        role: 'copy', effect: 'clone', confidence: 0.95 },
      { pattern: /becomes a copy of (target|a|another)/,
        role: 'copy', effect: 'clone', confidence: 0.9 },
      { pattern: /copy target (instant|sorcery|instant or sorcery|spell)/,
        role: 'copy', effect: 'copy_spell', confidence: 0.95 },
      { pattern: /copy (it|that spell).*you may choose new targets/,
        role: 'copy', effect: 'copy_spell', confidence: 0.9 },

      # Wheels
      { pattern: /each player discards .*(hand|their hand).*draws/,
        role: 'wheels', effect: 'wheel_effect', confidence: 0.95 },
      { pattern: /each player draws .* cards?.*each player discards/,
        role: 'wheels', effect: 'wheel_effect', confidence: 0.95 },
      { pattern: /shuffle .* hand .* into .* library.* draw/,
        role: 'wheels', effect: 'wheel_effect', confidence: 0.9 },

      # Graveyard Hate
      { pattern: /exile (all cards from )?.*graveyard|exile target player's graveyard/,
        role: 'graveyard_hate', effect: 'exile_graveyard', confidence: 0.9 },
      { pattern: /exile target card from .* graveyard/,
        role: 'graveyard_hate', effect: 'exile_graveyard', confidence: 0.85 },
      { pattern: /if .* card would .* put into .* graveyard .* exile (it|that card) instead/,
        role: 'graveyard_hate', effect: 'graveyard_prevention', confidence: 0.95 },
      { pattern: /cards in graveyards? lose all abilities/,
        role: 'graveyard_hate', effect: 'graveyard_prevention', confidence: 0.9 },

      # Group Hug
      { pattern: /each player (draws|discards .* then draws)/,
        role: 'group_hug', effect: 'group_draw', confidence: 0.8 },
      { pattern: /each player (may )?(search|searches) .* library for .* land/,
        role: 'group_hug', effect: 'group_ramp', confidence: 0.85 },
      { pattern: /each player gains .* life/,
        role: 'group_hug', effect: 'group_lifegain', confidence: 0.8 },

      # Voltron
      { pattern: /double strike/,
        role: 'voltron', effect: 'double_strike', confidence: 0.7 },
      { pattern: /protection from (white|blue|black|red|green|everything|all colors|each color)/,
        role: 'voltron', effect: 'protection_from', confidence: 0.75 }
    ].freeze

    def initialize(text:, results:)
      @text = text
      @results = results
    end

    def call
      PATTERNS.each do |rule|
        next unless @text.match?(rule[:pattern])

        add(role: rule[:role], effect: rule[:effect], confidence: rule[:confidence])
      end
    end

    private

    def add(role:, effect:, confidence:)
      key = [role, effect]
      existing = @results[key]
      return unless existing.nil? || confidence > existing[:confidence]

      @results[key] = { role: role, effect: effect, confidence: confidence, source: 'pattern' }
    end
  end
end
