module CardAnalysis
  # What does this commander actually want the other 99 to do?
  #
  # Everything here is already in the database - BatchProfiler has profiled all 107k cards into card_roles,
  # so the commander's own roles are a free lookup rather than a fresh text parse.
  class CommanderThemes < Service
    # Tribal is a real signal but a noisier one than the role taxonomy, so it is worth less than a role
    # the commander is tagged with at 0.9. Kept below twice the generic-role baseline as well: at 0.6 a
    # Goblin with any removal tag at all outscored every actual removal spell in the bucket.
    TRIBAL_WEIGHT = 0.45

    # "create a 1/1 white Cat Soldier creature token" says what a commander *makes*, not what it cares
    # about. Bounded to a single sentence so the strip cannot run past the clause it is aimed at.
    TOKEN_CLAUSE = /\bcreates?\b[^.]*?\btokens?\b/i

    def initialize(commander:)
      @commander = commander
    end

    # -> { role_weights: { [role, effect] => Float }, subtypes: [String], tribal_weight: Float }
    def call
      {
        role_weights: role_weights,
        subtypes: tribal_subtypes,
        tribal_weight: TRIBAL_WEIGHT
      }
    end

    private

    # Weight is the commander's own confidence in the role, so a commander tagged sacrifice at 0.9 pulls
    # harder on sacrifice cards than one tagged card_draw at 0.7. Below HIGH_CONFIDENCE the pattern rules
    # are guessing, and a guess is not a theme.
    def role_weights
      CardRole.for_oracle_id(@commander.scryfall_oracle_id)
              .high_confidence
              .to_h { |role| [[role.role, role.effect], role.confidence] }
    end

    # A subtype counts as tribal only when the commander's *rules text* names it - not merely because the
    # commander happens to be one.
    #
    # Krenko says "Goblins you control" and is a Goblin, so Goblin counts. Atraxa is a Phyrexian Angel
    # Horror and mentions none of them, so nothing counts - which is right, because Atraxa is a
    # proliferate deck, not an Angel deck. Taking the type line alone would make every legendary creature
    # look like a tribal commander.
    #
    # Token clauses are stripped before the scan, so a commander is not tribal for the tokens it makes:
    # Brimaz only ever says "Cat Soldier" inside the token he creates and is not a Cat deck. A commander
    # that genuinely cares names the type outside the clause too - Krenko sizes his tokens off "the number
    # of Goblins you control", Edgar Markov triggers on "another Vampire spell" - so real tribal survives.
    def tribal_subtypes
      words = subtype_words(@commander.text.to_s.gsub(TOKEN_CLAUSE, ' '))
      return [] if words.empty?

      # A tribe is a type that is *mostly* printed on creatures, which is what separates it from a type
      # that merely leaks onto a few: Goblin is 1,587 of 1,603 printings, while Saga is 85 of 504 (the
      # Final Fantasy enchantment creatures), Shrine 11 of 37 and Mountain 1 of 1,112. Requiring only one
      # creature printing let all three through as tribes. It also still drops subtypes that are ordinary
      # capitalised words - "You" is a real row in sub_types and matches partner reminder text - since
      # those are on no cards at all.
      SubType.joins(magic_card_sub_types: :magic_card)
             .where(name: words)
             .group('sub_types.id', 'sub_types.name')
             .having("COUNT(*) FILTER (WHERE magic_cards.card_type ILIKE '%creature%') * 2 > COUNT(*)")
             .pluck(:name)
    end

    # Rules text names a tribe in the plural when it cares about it ("the number of Goblins you control")
    # while sub_types stores the singular, so both forms have to reach the lookup. Once token clauses are
    # stripped the plural is often the *only* mention left, and dropping it would lose Krenko entirely.
    def subtype_words(text)
      words = text.scan(/\b[A-Z][a-z]+\b/)
      (words + words.map(&:singularize)).uniq
    end
  end
end
