module Commanders
  # How well does this collection support what this commander actually wants to do?
  #
  # Buildability alone cannot answer that. It is derived from the colour identity mask, so every
  # commander sharing an identity gets an identical score - all 313 mono-white commanders would show
  # the same bar, and ranking on it would just sort the format by colour count with the five-colour
  # commanders permanently on top. This is the axis that tells two Golgari commanders apart: one
  # wants sacrifice outlets, the other wants +1/+1 counters, and you own different numbers of each.
  #
  # Pure Ruby. The counts came from CollectionStats::BuildableProfile and BuildableTribes, already
  # summed over the commander's submasks by Buildability.
  class ThemeFit < Service
    # How many cards it takes to call a theme supported. Past this, more copies of the same idea stop
    # making the deck more buildable - the eleventh sacrifice outlet is not what is stopping you - so
    # each theme saturates instead of accumulating. Without the cap a commander themed into manabase
    # would outscore everything, because manabase is the role every collection has most of.
    SUPPORT = 8.0

    # A commander with no detected theme is not a bad brew, it is an unmeasured one - roughly a third
    # of the format has no high-confidence card_roles row at all (see the note in Discovery). Scoring
    # those at zero would bury them under commanders whose only advantage is being legible to the
    # taxonomy, so they sit mid-pack and let completeness and obscurity do the ordering.
    NEUTRAL = 0.5

    def initialize(role_weights:, subtypes:, effect_counts:, tribe_counts:)
      @role_weights = role_weights
      @subtypes = subtypes
      @effect_counts = effect_counts
      @tribe_counts = tribe_counts
    end

    # -> { score: 0.0..1.0, themed: Boolean, matched: [{ label:, owned: }] }
    def call
      supports = role_supports + tribal_supports
      return { score: NEUTRAL, themed: false, matched: [] } if supports.empty?

      { score: weighted_average(supports), themed: true, matched: matched(supports) }
    end

    private

    # [[label, weight, owned], ...]
    def role_supports
      @role_weights.map do |(role, effect), weight|
        [effect.to_s.humanize, weight, @effect_counts[[role, effect]].to_i]
      end
    end

    # Tribal rides on sub_types rather than card_roles - the role taxonomy has no concept of "is a
    # Goblin" - and is worth less than a role the commander is tagged with at 0.9, per the reasoning
    # on CardAnalysis::CommanderThemes::TRIBAL_WEIGHT.
    def tribal_supports
      @subtypes.map do |name|
        [name.pluralize, ThemeProfiles::TRIBAL_WEIGHT, @tribe_counts[name].to_i]
      end
    end

    # A weighted average rather than a sum, so a commander with six themes is not automatically
    # ahead of one with two. The question is "how well is this commander served", not "how many
    # things does it ask for".
    def weighted_average(supports)
      total = supports.sum { |_label, weight, _owned| weight }
      return NEUTRAL unless total.positive?

      earned = supports.sum { |_label, weight, owned| weight * saturation(owned) }

      (earned / total).round(4)
    end

    def saturation(owned)
      [owned / SUPPORT, 1.0].min
    end

    # Best-supported themes first - it is the "you already own 12 sacrifice outlets" line on the card,
    # so it should lead with the reason to brew this, not the reason not to.
    def matched(supports)
      supports.reject { |_label, _weight, owned| owned.zero? }
              .sort_by { |_label, _weight, owned| -owned }
              .first(3)
              .map { |label, _weight, owned| { label: label, owned: owned } }
    end
  end
end
