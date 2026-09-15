module Commanders
  # Groups scored suggestions into the role checklist the panel renders: "Ramp - 4 of 10".
  #
  # Every card lands in exactly one bucket. A ramp spell that also draws a card is interesting in both,
  # but showing it twice makes the panel read like it found twice as many options as it did.
  #
  # Fit is normalized inside each bucket rather than across the whole result, which is the difference
  # between the panel working and not. Normalizing globally means the commander's theme cards set the
  # maximum, every card in a generic bucket lands in a narrow 0.11-0.15 band, and obscurity - the only
  # axis left with any spread - decides the entire order. Per-bucket, "the best card_draw option here"
  # is a question with a real answer.
  class SuggestionBuckets < Service
    # The ranking weights live here rather than on the caller because this is the class that applies
    # them - score_for below is the only place any of them means anything.

    # How far obscurity may move an already-fitting card, as a multiplier around 1.0. At 0.8 the band
    # swings a card's score between 0.6x and 1.4x. Fit still leads; this only reorders cards that
    # already do the job.
    OBSCURITY_WEIGHT = 0.8

    # The two precon-corpus axes, deliberately well under OBSCURITY_WEIGHT: they refine the ordering
    # inside the obscurity band rather than overriding it. Both are boost-only, so each tops out at
    # 1.3x and neither has a floor that can push a card below its own fit.
    PRECON_WEIGHT = 0.3
    COOCCURRENCE_WEIGHT = 0.3

    # rubocop:disable Metrics/ParameterLists -- each weight is a distinct ranking axis, and folding
    # them into an options hash would hide from the caller that they are what the ordering is made of.
    def initialize(entries:, deck_role_counts:, roles:, per_bucket:,
                   obscurity_weight: OBSCURITY_WEIGHT, precon_weight: PRECON_WEIGHT,
                   cooccurrence_weight: COOCCURRENCE_WEIGHT)
      @entries = entries
      @deck_role_counts = deck_role_counts
      @roles = roles
      @per_bucket = per_bucket
      @obscurity_weight = obscurity_weight
      @precon_weight = precon_weight
      @cooccurrence_weight = cooccurrence_weight
    end
    # rubocop:enable Metrics/ParameterLists

    # -> [{ role:, target:, in_deck:, cards: [...] }], empty buckets dropped
    def call
      grouped = @entries.group_by { |entry| entry[:primary_role] }

      @roles.filter_map do |role|
        cards = grouped[role]
        next if cards.blank?

        {
          role: role,
          target: DeckTargets.for(role),
          in_deck: @deck_role_counts.fetch(role, 0),
          cards: rank_within(cards).first(@per_bucket)
        }
      end
    end

    private

    def rank_within(cards)
      max_fit = cards.pluck(:raw_fit).max
      max_fit = 1.0 unless max_fit&.positive?

      scored = cards.map { |entry| entry.merge(score_for(entry, max_fit)) }
      # Owned first: a card sitting in a binder is actionable tonight, one you do not own is a shopping
      # list. The blended score orders each half.
      scored.sort_by { |entry| [entry[:owned] ? 0 : 1, -entry[:score]] }
    end

    # Multiplicative, not a weighted sum. Fit has to lead - a card must actually do the thing before being
    # interesting for being unplayed - and under a weighted sum a card with no fit at all still scores
    # well on obscurity alone.
    #
    # Obscurity is centred on ObscurityScore::NEUTRAL so the multiplier cuts as well as boosts: a card
    # in the sweet spot of the band is worth more than its fit alone, and one at either end - a format
    # staple or a card at rank 25,000 - is worth less. A boost-only multiplier let a Goblin at rank
    # 26,941 lead the removal bucket on a tribal bonus, because nothing could pull it back down.
    #
    # The two precon axes are boost-only, and the asymmetry is deliberate rather than an oversight.
    # 83% of candidates appear in zero Commander precons because precons are budget- and
    # theme-constrained, so absence there is weak evidence of badness while presence is strong evidence
    # of playability. Centring them the way obscurity is centred would penalise the overwhelming
    # majority of the pool and hand the ordering back to the staples the obscurity band exists to
    # suppress. See CardAnalysis::PreconScore.
    #
    # They do not undo that suppression at these weights: Sol Ring lands at 0.6 x 1.3 = 0.78, a
    # mid-band card in eight precons at 1.4 x 1.15 = 1.61, and a mid-band card in none at 1.4.
    def score_for(entry, max_fit)
      fit = entry[:raw_fit] / max_fit
      obscurity = 1 + (@obscurity_weight * (entry[:obscurity] - CardAnalysis::ObscurityScore::NEUTRAL))
      precon = 1 + (@precon_weight * entry[:precon].to_f)
      cooccurrence = 1 + (@cooccurrence_weight * entry[:cooccurrence].to_f)

      { fit: fit.round(3), score: (fit * obscurity * precon * cooccurrence).round(4) }
    end
  end
end
