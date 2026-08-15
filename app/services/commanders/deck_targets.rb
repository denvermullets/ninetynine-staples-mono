module Commanders
  # Roughly how many slots a 99 wants per role. Not a rule - it is the yardstick the Suggestions panel
  # measures a deck against, so "Ramp - 4 of 10" means something without the reader knowing the format.
  #
  # Keys are CardRole::ROLES entries. Roles not listed here (tokens, sacrifice, voltron, ...) are
  # archetype roles: they matter when a commander themes into them, but there is no universal target for
  # how much sacrifice a deck should run.
  #
  # Also read by the collection buildability profile, so keep it a bare constant with no logic.
  class DeckTargets
    # Order matters: it is the order the Suggestions panel lists generic buckets in, and manabase sits last
    # on purpose. It is the largest target by a wide margin and the least useful thing to be told about -
    # nobody needs a recommendation engine to find lands.
    TARGETS = {
      'ramp' => 10,
      'removal' => 8,
      'card_draw' => 10,
      'protection' => 4,
      'tutor' => 3,
      'recursion' => 3,
      'manabase' => 36
    }.freeze

    ROLES = TARGETS.keys.freeze

    def self.for(role)
      TARGETS[role]
    end
  end
end
