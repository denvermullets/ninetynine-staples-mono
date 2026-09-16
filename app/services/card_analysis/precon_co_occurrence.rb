module CardAnalysis
  # Which cards travel with the cards already in the deck, measured across the Commander precon corpus.
  #
  # This is the axis that keys off the deck in progress rather than the commander. A direct
  # per-commander lookup would answer almost nobody - the corpus covers 161 of 3,235 commanders, 5% -
  # but "what goes with these cards" generalises to any deck with cards in it.
  #
  # MEASURED PAIRWISE, NOT PER DECK. The obvious form - find precons sharing any of the deck's cards,
  # count what else is in them - collapses completely: with a 90-card anchor set every one of the 176
  # decks matches on Sol Ring or a basic, so P(candidate | anchors) equals P(candidate) and the lift
  # comes out 1.0 for every card in the corpus. Averaging P(candidate | anchor) over the individual
  # anchors is what actually carries signal, because a card that only travels with dragons scores
  # against the dragon anchors and nothing else.
  #
  # It degrades honestly. A deck with nothing in common with WotC's mainline precons - a crossover
  # product, say - returns lift ~1.0 across the board rather than inventing an ordering.
  #
  # Averaging over EVERY anchor, including the ones a card never appears with, is deliberate and it
  # makes this axis quiet by design. An anchor that never co-occurs contributes a zero, so a card is
  # pulled down by the parts of the deck it has nothing to do with, and lift is only comparable within
  # a single call rather than against any fixed threshold.
  #
  # The two alternatives were measured and are worse. Averaging only over anchors that do co-occur put
  # 1,055 of 1,157 candidates above 1.0 on a real 86-card deck - a boost for almost everything is not
  # information. Taking the strongest single anchor is degenerate: it ties at 1/base for every card
  # seen in one deck with any anchor, so it ranks rarity, not affinity.
  #
  # What that buys is an axis that says nothing when it knows nothing. A deck built out of precon
  # archetypes lights it up - 71 anchors from a dragon precon put Atarka, World Render at 20.3x, with
  # no ubiquitous card in the top ten - while a custom 86-card list scored only 8 candidates above 1.0,
  # all of them on-colour manabase and ramp. Staying silent is the right answer for the second case.
  class PreconCoOccurrence < Service
    def initialize(anchor_oracle_ids:)
      @anchors = Array(anchor_oracle_ids).map(&:to_s).uniq
    end

    # -> { oracle_id => { lift:, support: } }
    #
    # `support` is how many precons the candidate appears in at all. Lift on a card seen once is
    # arithmetic, not evidence, so the caller gates on it - see PreconScore::MIN_SUPPORT.
    def call
      return {} if @anchors.empty?

      totals = deck_counts
      total_decks = PreconCorpus.total_decks
      return {} if total_decks.zero?

      anchor_count = @anchors.size.to_f
      anchor_set = @anchors.to_set

      conditional_totals.each_with_object({}) do |(oracle_id, sum_conditional), result|
        next if anchor_set.include?(oracle_id)

        support = totals.fetch(oracle_id, 0)
        # Laplace-smoothed base rate: a card in one precon should not divide its way to a huge lift.
        base = (support + 1).to_f / (total_decks + 1)

        result[oracle_id] = { lift: (sum_conditional / anchor_count) / base, support: support }
      end
    end

    private

    # SUM over anchors A of P(candidate | A), in one pass. The self-join is over the corpus CTE rather
    # than a materialised pair table: the anchor side is bounded by the deck (100 cards at most) and
    # the corpus is 176 decks of ~87 cards, so this stays a small join - measured at 41ms for 8
    # anchors and 153ms for 92, against a table with no derived rows to keep fresh.
    def conditional_totals
      sql = sanitize(<<~SQL, @anchors, @anchors)
        WITH deck_cards AS (#{PreconCorpus::DECK_CARDS_SQL}),
        anchor_totals AS (
          SELECT oracle_id, COUNT(DISTINCT deck_id) AS n
          FROM deck_cards WHERE oracle_id IN (?) GROUP BY oracle_id
        ),
        pairs AS (
          SELECT a.oracle_id AS anchor_id, c.oracle_id AS cand_id, COUNT(DISTINCT a.deck_id) AS n
          FROM deck_cards a
          JOIN deck_cards c ON c.deck_id = a.deck_id AND c.oracle_id <> a.oracle_id
          WHERE a.oracle_id IN (?)
          GROUP BY a.oracle_id, c.oracle_id
        )
        SELECT pairs.cand_id, SUM(pairs.n::float / anchor_totals.n) AS sum_conditional
        FROM pairs
        JOIN anchor_totals ON anchor_totals.oracle_id = pairs.anchor_id
        GROUP BY pairs.cand_id
      SQL

      connection.select_rows(sql).map { |oracle_id, sum| [oracle_id, sum.to_f] }
    end

    def deck_counts
      connection.select_rows(<<~SQL).to_h { |oracle_id, count| [oracle_id, count.to_i] }
        SELECT oracle_id, COUNT(DISTINCT deck_id)
        FROM (#{PreconCorpus::DECK_CARDS_SQL}) deck_cards
        GROUP BY oracle_id
      SQL
    end

    def sanitize(sql, *binds)
      ActiveRecord::Base.sanitize_sql_array([sql, *binds])
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
