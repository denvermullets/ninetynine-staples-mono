module CardAnalysis
  # Turns the two precon corpus measurements into 0..1 scores the bucket ranking can multiply by.
  #
  # Both are BOOST-ONLY, and that asymmetry is the whole design. 83% of candidates appear in zero
  # Commander precons - measured, 532 of 3,096 removal candidates have any appearance at all - because
  # precons are budget-constrained and theme-constrained, not because five sixths of Magic is
  # unplayable. So absence is weak evidence of badness while presence is strong evidence of
  # playability, and the scoring has to be shaped like the evidence.
  #
  # This is the difference from ObscurityScore, which is centred on NEUTRAL and cuts as well as
  # boosts. Centring these the same way would penalise the overwhelming majority of the pool and hand
  # the ranking straight back to the format staples the obscurity band exists to suppress.
  class PreconScore
    # Rate at which inclusion scores 0.5. Saturating rather than linear: the interesting distinction
    # is between zero, a little and a lot, not between a lot and slightly more. 0.01 -> 0.17,
    # 0.05 -> 0.5, 0.30 -> 0.86, and it is bounded without a clamp or a cliff.
    HALF = 0.05

    # Lift on one or two appearances is arithmetic, not evidence: a card in a single precon that
    # happens to be one the anchors match scores enormously and means nothing.
    MIN_SUPPORT = 3

    # Where co-occurrence saturates. 3x the base rate is already a strong statement that a card
    # travels with this kind of deck; measured tops out around 20x on a tribal deck, and letting that
    # run linearly would let one anchor match dominate a bucket.
    LIFT_REFERENCE = 3.0

    def inclusion(rate)
      return 0.0 if rate.nil? || rate <= 0

      rate / (rate + HALF)
    end

    def cooccurrence(lift:, support:)
      return 0.0 if lift.nil? || support.to_i < MIN_SUPPORT

      ((lift - 1.0) / (LIFT_REFERENCE - 1.0)).clamp(0.0, 1.0)
    end
  end
end
