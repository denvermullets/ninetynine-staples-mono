module CardAnalysis
  # How often WotC designers reach for a card, as a rate rather than a count.
  #
  # This is the "is it actually playable" signal card_roles cannot provide. The role taxonomy is
  # regex-derived: it can tell that a card destroys a creature, not whether the card is worth a slot.
  # Inside a generic bucket that leaves every candidate scoring nearly the same, and the ordering
  # falls to obscurity alone. A card in 40 of 176 precons is a card designers reach for; one in zero
  # is not, and that difference is real information about quality that is already in the database.
  #
  # THE DENOMINATOR IS ELIGIBILITY, NOT 176. A white removal spell can only appear in the 99 precons
  # whose identity contains white; a colourless mana rock can appear in all 176. Counting raw
  # appearances systematically favours colourless cards over coloured ones for no reason other than
  # how many decks were legally able to run them. Measured on the removal role, the raw count puts
  # Swords to Plowshares (37) over Putrefy (17); normalised by eligible decks, Putrefy (17/40) is
  # correctly ahead of Swords (37/99).
  class PreconInclusion < Service
    # Added to the eligible-deck denominator so a card that showed up in 3 of the 10 five-colour
    # precons does not read like a staple. Three-colour identities have as few as 10 eligible decks,
    # where a single appearance moves the rate by 10 points; Crackling Doom at 5/22 and Naya Charm at
    # 5/24 are exactly the noise this is here to damp.
    SMOOTHING = 25

    def initialize(oracle_ids:)
      @oracle_ids = Array(oracle_ids).map(&:to_s).uniq
    end

    # -> { oracle_id => { deck_count:, eligible:, rate: } }
    #
    # Only cards that appear in at least one Commander precon get an entry. 83% of candidates appear
    # in none, and an entry full of zeroes for each of them is a bigger hash to say nothing with.
    def call
      return {} if @oracle_ids.empty?

      eligible = eligible_deck_counts

      counts.each_with_object({}) do |(oracle_id, deck_count, mask), result|
        seats = eligible.fetch(mask, 0)

        result[oracle_id] = { deck_count: deck_count,
                              eligible: seats,
                              rate: deck_count.to_f / (seats + SMOOTHING) }
      end
    end

    private

    # One statement: the appearance count and the card's colour identity are needed together, and the
    # identity is only wanted for cards that actually appeared.
    #
    # BIT_OR aggregates over every printing rather than picking a representative one - identity is a
    # property of the card, so all its printings agree - which avoids a MAX(id) subquery to choose.
    def counts
      sql = sanitize(<<~SQL, @oracle_ids)
        WITH deck_cards AS (#{PreconCorpus::DECK_CARDS_SQL}),
        counted AS (
          SELECT oracle_id, COUNT(DISTINCT deck_id) AS deck_count
          FROM deck_cards WHERE oracle_id IN (?) GROUP BY oracle_id
        )
        SELECT counted.oracle_id, counted.deck_count, #{Commanders::ColorMask::IDENTITY_MASK} AS mask
        FROM counted
        JOIN magic_cards ON magic_cards.scryfall_oracle_id::text = counted.oracle_id
        LEFT JOIN magic_card_color_idents ON magic_card_color_idents.magic_card_id = magic_cards.id
        LEFT JOIN colors ON colors.id = magic_card_color_idents.color_id
        GROUP BY counted.oracle_id, counted.deck_count
      SQL

      connection.select_rows(sql).map { |oracle_id, deck_count, mask| [oracle_id, deck_count.to_i, mask.to_i] }
    end

    # -> { mask => how many Commander precons could legally run a card of that identity }
    #
    # A deck's identity is its commander's, and BIT_OR over the commander board merges partners for
    # free: two commanders in one deck aggregate into the one identity the deck actually plays.
    def eligible_deck_counts
      deck_masks = connection.select_rows(<<~SQL).map { |_deck_id, mask| mask.to_i }
        SELECT pdc.precon_deck_id, #{Commanders::ColorMask::IDENTITY_MASK} AS mask
        FROM precon_deck_cards pdc
        JOIN precon_decks pd ON pd.id = pdc.precon_deck_id
        LEFT JOIN magic_card_color_idents ON magic_card_color_idents.magic_card_id = pdc.magic_card_id
        LEFT JOIN colors ON colors.id = magic_card_color_idents.color_id
        WHERE pd.deck_type = '#{PreconCorpus::DECK_TYPE}' AND pdc.board_type = 'commander'
        GROUP BY pdc.precon_deck_id
      SQL

      Commanders::ColorMask::MASKS.index_with do |mask|
        deck_masks.count { |deck_mask| mask & deck_mask == mask }
      end
    end

    # A bare array bind raises "can't cast Array" through exec_query, so the list goes through
    # sanitize_sql_array rather than a positional parameter.
    def sanitize(sql, *binds)
      ActiveRecord::Base.sanitize_sql_array([sql, *binds])
    end

    def connection
      ActiveRecord::Base.connection
    end
  end
end
