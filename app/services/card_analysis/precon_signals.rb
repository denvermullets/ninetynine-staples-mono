module CardAnalysis
  # Attaches the two precon-corpus axes to scored suggestion entries.
  #
  # Separate from CommanderSynergy because it is a self-contained pass over already-built entries:
  # it needs the oracle ids and the deck's own cards, nothing else about the commander.
  class PreconSignals < Service
    def initialize(entries:, anchor_oracle_ids: [])
      @entries = entries
      @anchors = anchor_oracle_ids
    end

    # -> the same entries, each with precon_decks, precon and cooccurrence merged in.
    def call
      return @entries if @entries.empty?

      score = PreconScore.new
      inclusion = PreconInclusion.call(oracle_ids: @entries.pluck(:oracle_id))
      cooccurrence = pair_stats

      @entries.map do |entry|
        stats = inclusion[entry[:oracle_id]]
        pair = cooccurrence[entry[:oracle_id]]

        entry.merge(
          precon_decks: stats ? stats[:deck_count] : 0,
          precon: score.inclusion(stats && stats[:rate]).round(3),
          cooccurrence: score.cooccurrence(lift: pair && pair[:lift], support: pair && pair[:support]).round(3)
        )
      end
    end

    private

    # Anchored on the deck's own cards, so there is nothing to measure until the deck has some. A deck
    # that is still just a commander gets an empty hash rather than a guess - the corpus covers 161 of
    # 3,235 commanders, and inventing an ordering for the other 95% would be worse than silence.
    def pair_stats
      return {} if @anchors.blank?

      PreconCoOccurrence.call(anchor_oracle_ids: @anchors)
    end
  end
end
