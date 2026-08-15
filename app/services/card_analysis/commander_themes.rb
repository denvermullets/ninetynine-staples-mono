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
    # False positive worth knowing: a commander whose only tribal mention is the token it makes ("create a
    # 1/1 Soldier") reads as Soldier tribal. TRIBAL_WEIGHT keeps that from dominating a bucket.
    def tribal_subtypes
      words = @commander.text.to_s.scan(/\b[A-Z][a-z]+\b/).uniq
      return [] if words.empty?

      # The creature join filters out subtypes that are also ordinary capitalised words in rules text -
      # "You" is a real row in sub_types and matches the reminder text on half the partner commanders.
      SubType.joins(magic_card_sub_types: :magic_card)
             .where(name: words)
             .where('magic_cards.card_type ILIKE ?', '%creature%')
             .distinct.pluck(:name)
    end
  end
end
