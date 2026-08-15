module CardAnalysis
  # Turns magic_cards.edhrec_rank into a 0..1 "is this an overlooked card" score.
  #
  # This is NOT the inverse of EdhrecRankBlender, and it is not a straight inversion of rank either.
  # A straight inversion was tried first and produced exactly what the ticket warned about: the top of
  # every bucket was Turtle Blimp, Electric Seaweed and Casey Jones, Vigilante - cards at rank 20,000+
  # that are unplayed because they are bad, not because they are overlooked.
  #
  # So obscurity is a band, not an axis. It peaks in the middle of the log-rank range and falls off at
  # both ends: format staples score near zero because everyone already runs them, and bulk scores near
  # zero because nobody runs them for a reason. What is left in the middle is the actual target - cards
  # that see real play but are not the default answer.
  class ObscurityScore
    # Where the band peaks, as a fraction of the log-rank range. 0.75 lands around EDHREC rank ~2,500,
    # with the useful shoulder running roughly rank 800-8,000.
    PEAK = 0.75

    # Unranked is not obscure - it usually means a card too new for anyone to have an opinion - and
    # letting nulls sort to the top would fill every bucket with cards nobody has evaluated.
    NEUTRAL = 0.5

    # A fixed scale, not MagicCard.maximum(:edhrec_rank). Reading the max out of the table would make a
    # card's obscurity depend on how much of the card pool happens to be ingested - which is the same
    # flaw EdhrecRankBlender has with its candidate-set max, and the reason this class does not reuse it.
    # 30,000 is roughly where EDHREC's rank space currently ends; anything past it clamps to bulk, which
    # is the right answer anyway.
    REFERENCE_MAX_RANK = 30_000

    def initialize(max_rank: REFERENCE_MAX_RANK)
      @log_max = Math.log(max_rank + 1)
    end

    def score(rank)
      return NEUTRAL if rank.nil?

      # Log scale because ranks cluster hard at the top: the distance from rank 1 to 500 is a different
      # kind of distance than 20,000 to 20,500.
      position = [Math.log(rank + 1) / @log_max, 1.0].min
      distance = (position - PEAK).abs
      span = position < PEAK ? PEAK : 1.0 - PEAK

      [1.0 - (distance / span), 0.0].max
    end
  end
end
