module Commanders
  # What a commander in this colour identity could actually be built from, measured against the
  # collection profile.
  #
  # Pure Ruby - the query already happened in CollectionStats::BuildableProfile. A commander's legal
  # pool is the sum over the submasks of its own identity, and because every card sits in exactly one
  # mask bucket, that sum is an exact distinct count with nothing double-counted. Eight lookups for a
  # three-colour commander, not a scan.
  class Buildability < Service
    # MANABASE IS EXCLUDED FROM COMPLETENESS ON PURPOSE. Its target is 36 of the 74 slots in
    # DeckTargets::TARGETS, and basics fill any gap in it for free, so leaving it in the denominator
    # reports every collection as roughly half-complete before a single spell has been counted -
    # which makes the bar useless for telling two commanders apart. It is reported as its own figure
    # instead. DeckTargets' own comment already calls manabase the least useful thing to be told
    # about; this is that comment applied to the denominator.
    SPELL_ROLES = (DeckTargets::ROLES - ['manabase']).freeze

    SPELL_SLOTS = SPELL_ROLES.sum { |role| DeckTargets.for(role) }

    def initialize(profile:, mask:)
      @profile = profile
      @mask = mask
    end

    # -> { owned_pool:, role_coverage:, effect_counts:, completeness:, bottleneck:, manabase: }
    def call
      coverage = role_coverage

      {
        owned_pool: buckets.sum { |bucket| bucket[:distinct_cards] },
        role_coverage: coverage,
        effect_counts: summed_effects,
        completeness: completeness(coverage),
        bottleneck: bottleneck(coverage),
        manabase: coverage.fetch('manabase', nil)
      }
    end

    private

    def buckets
      @buckets ||= ColorMask.submasks(@mask).filter_map { |submask| @profile[submask] }
    end

    def summed_roles
      @summed_roles ||= sum_counts(buckets.map { |bucket| bucket[:role_counts] })
    end

    def summed_effects
      @summed_effects ||= sum_counts(buckets.map { |bucket| bucket[:effect_counts] })
    end

    def sum_counts(hashes)
      hashes.each_with_object(Hash.new(0)) do |counts, totals|
        counts.each { |key, count| totals[key] += count }
      end
    end

    # Every target role, including the ones with nothing owned - a zero is the most useful row on the
    # page, because it is the reason the deck cannot be built.
    def role_coverage
      DeckTargets::ROLES.index_with do |role|
        target = DeckTargets.for(role)
        owned = summed_roles[role].to_i

        { owned: owned, target: target, short: [target - owned, 0].max,
          share: ([owned, target].min.fdiv(target) * 100).round(1) }
      end
    end

    # min(owned, target) so a collection with 40 ramp cards does not bank the surplus against a role
    # it has nothing for - you cannot fill a removal slot with a Sol Ring.
    def completeness(coverage)
      filled = SPELL_ROLES.sum { |role| [coverage[role][:owned], coverage[role][:target]].min }

      filled.fdiv(SPELL_SLOTS).round(4)
    end

    # Ties break on DeckTargets' own order, which puts the roles a deck misses most painfully first.
    def bottleneck(coverage)
      SPELL_ROLES.max_by { |role| coverage[role][:short] }
                 .then { |role| coverage[role][:short].positive? ? role : nil }
    end
  end
end
