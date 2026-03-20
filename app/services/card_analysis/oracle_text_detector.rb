module CardAnalysis
  class OracleTextDetector
    SIMPLE_PATTERNS = [
      { pattern: /counter target spell/, role: 'protection', effect: 'counterspell', confidence: 0.95 },
      { pattern: /hexproof/, role: 'protection', effect: 'hexproof_grant', confidence: 0.75 },
      { pattern: /indestructible/, role: 'protection', effect: 'indestructible_grant', confidence: 0.75 },
      { pattern: /ward \{/, role: 'protection', effect: 'ward_grant', confidence: 0.7 },
      { pattern: /phase(s)? out/, role: 'protection', effect: 'phase_out', confidence: 0.8 },
      { pattern: /(gains?|has) flying/, role: 'evasion', effect: 'flying_grant', confidence: 0.75 },
      { pattern: /(gains?|has) trample/, role: 'evasion', effect: 'trample_grant', confidence: 0.75 },
      { pattern: /(gains?|has) menace/, role: 'evasion', effect: 'menace_grant', confidence: 0.75 },
      { pattern: /can't be blocked|unblockable/, role: 'evasion', effect: 'unblockable', confidence: 0.85 },
      { pattern: /take an extra turn/, role: 'finisher', effect: 'extra_turns', confidence: 0.95 },
      { pattern: /you win the game/, role: 'finisher', effect: 'alt_wincon', confidence: 0.95 },
      { pattern: /populate/, role: 'tokens', effect: 'populate', confidence: 0.9 },
      { pattern: /gain \d+ life|you gain life equal to/, role: 'lifegain', effect: 'life_gain', confidence: 0.8 },
      { pattern: /whenever you gain life/, role: 'lifegain', effect: 'lifegain_payoff', confidence: 0.9 },
      { pattern: /whenever you sacrifice/, role: 'sacrifice', effect: 'aristocrat_payoff', confidence: 0.9 },
      { pattern: /scry \d+/, role: 'card_draw', effect: 'card_selection', confidence: 0.5 },
      { pattern: /destroy target (creature|artifact|enchantment|permanent|planeswalker)/,
        role: 'removal', effect: 'targeted_removal', confidence: 0.95 },
      { pattern: /destroy all (creatures|permanents|nonland permanents)/,
        role: 'removal', effect: 'board_wipe', confidence: 0.95 },
      { pattern: /exile target (creature|artifact|enchantment|permanent|planeswalker)/,
        role: 'removal', effect: 'exile_removal', confidence: 0.95 },
      { pattern: /exile all (creatures|permanents|nonland permanents)/,
        role: 'removal', effect: 'board_wipe', confidence: 0.95 },
      { pattern: /target (player|opponent) sacrifices (a|an) (creature|permanent)/,
        role: 'removal', effect: 'sacrifice_removal', confidence: 0.85 },
      { pattern: /return target .* to (its|their) owner('s|s') hand/,
        role: 'removal', effect: 'bounce', confidence: 0.85 },
      { pattern: /(deal|deals) \d+ damage to (target|any target|each)/,
        role: 'removal', effect: 'targeted_removal', confidence: 0.7 },
      { pattern: /draw (a card|two cards|three cards|\d+ cards|cards equal to)/,
        role: 'card_draw', effect: 'draw', confidence: 0.9 },
      { pattern: /exile the top .* card.* (you may play|you may cast|play .* this turn|cast .* this turn)/,
        role: 'card_draw', effect: 'impulse_draw', confidence: 0.85 },
      { pattern: /draw a card.* then discard|discard .* then draw|draw .* discard/,
        role: 'card_draw', effect: 'loot', confidence: 0.85 },
      { pattern: /look at the top .* cards? .* put .* (into your hand|on top)/,
        role: 'card_draw', effect: 'card_selection', confidence: 0.8 },
      { pattern: /sacrifice (a|another) (creature|permanent|artifact).*:/,
        role: 'sacrifice', effect: 'sacrifice_outlet', confidence: 0.9 },
      { pattern: /whenever .* (dies|is put into .* graveyard from the battlefield)/,
        role: 'sacrifice', effect: 'death_trigger', confidence: 0.85 },
      { pattern: /lose(s)? .* life .* you gain|each opponent loses .* life .* you gain/,
        role: 'lifegain', effect: 'life_drain', confidence: 0.85 },
      { pattern: /landfall|whenever a land enters the battlefield under your control/,
        role: 'lands_matter', effect: 'landfall_payoff', confidence: 0.85 },
      { pattern: /(return|put) .* land .* from .* graveyard/,
        role: 'lands_matter', effect: 'land_recursion', confidence: 0.85 },
      { pattern: /land(s)? you control .* become .* creature/,
        role: 'lands_matter', effect: 'land_animation', confidence: 0.8 }
    ].freeze

    def initialize(oracle_text, card_type)
      @text = oracle_text
      @card_type = card_type
    end

    def detect(results)
      detect_simple_patterns(results)
      detect_ramp(results)
      detect_tutor(results)
      detect_recursion(results)
      detect_tokens_and_pump(results)
      detect_lands_extra(results)
    end

    private

    def match?(pattern)
      @text.match?(pattern)
    end

    def add(results, role:, effect:, confidence:)
      key = [role, effect]
      existing = results[key]
      return unless existing.nil? || confidence > existing[:confidence]

      results[key] = { role: role, effect: effect, confidence: confidence, source: 'pattern' }
    end

    def detect_simple_patterns(results)
      SIMPLE_PATTERNS.each do |rule|
        next unless match?(rule[:pattern])

        add(results, role: rule[:role], effect: rule[:effect], confidence: rule[:confidence])
      end
    end

    def detect_ramp(results)
      detect_mana_producers(results)
      if match?(/add \{[wubrgc]\}.*\{[wubrgc]\}/i) && match?(/sacrifice|until end of turn|exile .* at/)
        add(results, role: 'ramp', effect: 'ritual', confidence: 0.8)
      end
      return unless match?(/spells? (you cast )?cost(s)? \{?\d?\}? ?(less|fewer)/) ||
                    match?(/reduce the cost/)

      add(results, role: 'ramp', effect: 'cost_reduction', confidence: 0.85)
    end

    def detect_mana_producers(results)
      if match?(/search your library for .*(basic land|land card).*put.*(onto the battlefield|into play)/)
        add(results, role: 'ramp', effect: 'land_ramp', confidence: 0.95)
      end
      if @card_type.include?('creature') && match?(/\{t\}: add \{/)
        add(results, role: 'ramp', effect: 'mana_dork', confidence: 0.95)
      end
      return unless @card_type.include?('artifact') && !@card_type.include?('creature') && match?(/\{t\}: add \{/)

      add(results, role: 'ramp', effect: 'mana_rock', confidence: 0.95)
    end

    def detect_tutor(results)
      if match?(/search your library for a card.*put.*(into your hand|in your hand)/)
        add(results, role: 'tutor', effect: 'tutor_to_hand', confidence: 0.95)
      end
      if match?(/search your library for a card.*put.*on top of your library/)
        add(results, role: 'tutor', effect: 'tutor_to_top', confidence: 0.95)
      end
      type_re = /search your library for .*(creature|artifact|enchantment|permanent|planeswalker)/
      return unless match?(type_re) && match?(/card.*put.*(onto the battlefield|into play)/)

      add(results, role: 'tutor', effect: 'tutor_to_battlefield', confidence: 0.9)
    end

    def detect_recursion(results)
      if match?(/(return|put) .* from .*(your )?graveyard .*(to your hand|into your hand)/)
        add(results, role: 'recursion', effect: 'graveyard_to_hand', confidence: 0.9)
      end
      if match?(/(return|put) .* from .*(your )?graveyard .*(to the battlefield|onto the battlefield)/)
        add(results, role: 'recursion', effect: 'graveyard_to_battlefield', confidence: 0.9)
      end
      reanimate_re = /(return|put) .* creature .* from .* graveyard/
      return unless match?(reanimate_re) && match?(/(to the battlefield|onto the battlefield)/)

      add(results, role: 'recursion', effect: 'reanimate', confidence: 0.9)
    end

    def detect_tokens_and_pump(results)
      add(results, role: 'tokens', effect: 'token_creation', confidence: 0.9) if match?(%r{create .* \d+/\d+ .* token})
      if match?(%r{creatures you control get \+\d+/\+\d+}) || match?(%r{other creatures you control .* \+\d+/\+\d+})
        add(results, role: 'tokens', effect: 'token_anthem', confidence: 0.8)
        add(results, role: 'pump', effect: 'anthem', confidence: 0.85)
      end
      return unless match?(%r{target (creature|permanent) gets \+\d+/\+\d+ until end of turn})

      add(results, role: 'pump', effect: 'combat_trick', confidence: 0.85)
    end

    def detect_lands_extra(results)
      return unless match?(/play an additional land/) || match?(/you may play an additional land/)

      add(results, role: 'lands_matter', effect: 'extra_land_drop', confidence: 0.95)
    end
  end
end
