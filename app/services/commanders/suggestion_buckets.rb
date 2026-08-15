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
    def initialize(entries:, deck_role_counts:, roles:, per_bucket:, obscurity_weight:)
      @entries = entries
      @deck_role_counts = deck_role_counts
      @roles = roles
      @per_bucket = per_bucket
      @obscurity_weight = obscurity_weight
    end

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
    # Centred on ObscurityScore::NEUTRAL so the multiplier cuts as well as boosts: a card in the sweet
    # spot of the band is worth more than its fit alone, and one at either end - a format staple or a
    # card at rank 25,000 - is worth less. A boost-only multiplier let a Goblin at rank 26,941 lead the
    # removal bucket on a tribal bonus, because nothing could pull it back down.
    def score_for(entry, max_fit)
      fit = entry[:raw_fit] / max_fit
      multiplier = 1 + (@obscurity_weight * (entry[:obscurity] - CardAnalysis::ObscurityScore::NEUTRAL))

      { fit: fit.round(3), score: (fit * multiplier).round(4) }
    end
  end
end
