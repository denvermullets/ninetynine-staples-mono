module Commanders
  # CardAnalysis::CommanderThemes, for a whole page of commanders at once.
  #
  # That class asks the same two questions this one does, and answers them correctly - but it fires
  # two queries per commander. The brew page scores every commander in the format, so calling it in a
  # loop would be 6,470 round trips. This is the batched form: TWO QUERIES TOTAL, regardless of how
  # many commanders are passed in.
  #
  # CommanderThemes keeps its single-commander shape and CommanderSynergy keeps calling it. The two
  # must agree on what a theme is, so the rules are duplicated deliberately and briefly rather than
  # extracted - see the notes on each method for where they mirror it.
  class ThemeProfiles < Service
    # Same weight CommanderThemes uses, referenced rather than redefined.
    TRIBAL_WEIGHT = CardAnalysis::CommanderThemes::TRIBAL_WEIGHT

    # Capitalised words in rules text, the candidate tribal mentions. Same expression
    # CommanderThemes#tribal_subtypes scans with.
    WORD = /\b[A-Z][a-z]+\b/

    # commanders: [[oracle_id, text], ...]
    def initialize(commanders:)
      @commanders = commanders
    end

    # -> { oracle_id => { role_weights: { [role, effect] => Float }, subtypes: [String] } }
    def call
      return {} if @commanders.empty?

      weights = role_weights
      names = creature_subtypes

      @commanders.to_h do |oracle_id, text|
        [oracle_id, { role_weights: weights.fetch(oracle_id, {}), subtypes: tribal(text, names) }]
      end
    end

    private

    # The commander's own card_roles rows, weighted by its own confidence, so a commander tagged
    # sacrifice at 0.9 pulls harder than one tagged card_draw at 0.7. Below HIGH_CONFIDENCE the
    # pattern rules are guessing, and a guess is not a theme.
    #
    # ~3,142 rows for the whole format in 38ms, which is why this is worth doing in one query and
    # not worth caching.
    def role_weights
      CardRole.high_confidence
              .where(scryfall_oracle_id: @commanders.map(&:first))
              .pluck(:scryfall_oracle_id, :role, :effect, :confidence)
              .group_by(&:first)
              .transform_values { |rows| rows.to_h { |_id, role, effect, conf| [[role, effect], conf] } }
    end

    # A subtype counts only when the commander's RULES TEXT names it, not merely because the commander
    # happens to be one - Atraxa is a Phyrexian Angel Horror and mentions none of them, because Atraxa
    # is a proliferate deck and not an Angel deck.
    #
    # CommanderThemes enforces the "is it really a creature type" half with a per-commander join
    # against sub_types. Here the whole valid set - 377 names - is loaded once and intersected in
    # Ruby, which gives the same answer without a query per commander. The creature filter is what
    # throws out capitalised words that are also sub_types rows, "You" being the one that matches the
    # reminder text on half the partner commanders.
    #
    # ONE DELIBERATE DIVERGENCE: the plural is matched too. CommanderThemes compares the scanned word
    # to sub_types.name directly, so it reads "Goblin creature tokens" but not "Goblins you control" -
    # which is the commonest tribal phrasing there is, and the one a tribal lord uses. Krenko happens
    # to say both, which is why the gap has not bitten the suggestions panel. Worth folding back into
    # CommanderThemes; until then this is the side that is right.
    def tribal(text, names)
      words = text.to_s.scan(WORD)
      return [] if words.empty?

      words.flat_map { |word| [word, word.singularize] }.uniq & names
    end

    def creature_subtypes
      @creature_subtypes ||= SubType.joins(magic_card_sub_types: :magic_card)
                                    .where('magic_cards.card_type ILIKE ?', '%creature%')
                                    .distinct.pluck(:name)
    end
  end
end
