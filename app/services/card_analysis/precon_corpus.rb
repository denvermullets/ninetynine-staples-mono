module CardAnalysis
  # What counts as "a Commander precon", in one place, so PreconInclusion and PreconCoOccurrence
  # cannot drift apart on the question.
  #
  # This is a real, local, hand-built deck corpus: 176 decks a designer sat down and assembled. It is
  # not a popularity consensus and carries no undocumented metric - a card is either in a WotC-designed
  # 100 or it is not, and the whole list is readable. That is the reason it is worth reading at all,
  # and the reason STA-271's EDHREC dependency was rejected.
  module PreconCorpus
    # ONLY 'Commander Deck'. PreconDeck.deck_type carries 30+ values and three of them look tempting:
    # 'Brawl Deck' (4) and 'Historic Brawl Precon Deck' (5) are 60-card singleton in a different
    # format, and 'MTGO Commander Deck' (2) are digital duplicates of paper decks already counted
    # here, which would silently double-weight whatever is in them.
    DECK_TYPE = 'Commander Deck'.freeze

    # 'tokens' is excluded outright - a token is not a card you can be suggested. There are zero
    # 'sideBoard' rows across every Commander precon, so omitting it costs nothing.
    BOARD_TYPES = %w[mainBoard commander].freeze

    QUOTED_BOARD_TYPES = BOARD_TYPES.map { |board| "'#{board}'" }.join(', ').freeze

    # A frozen constant rather than a method, for the same reason Commanders::ColorMask::BIT_CASE is:
    # Brakeman cannot prove a method call interpolated into SQL is constant and flags it as injection,
    # and brakeman runs in the pre-commit hook.
    #
    # Keyed on oracle id, not magic_card_id: precon_deck_cards points at a printing, and "is this card
    # in precons" is a question about the card. Casting on the magic_cards side keeps the uuid/string
    # mismatch with card_roles from costing an index - see CollectionStats::MaskedOracles.
    DECK_CARDS_SQL = <<~SQL.squish.freeze
      SELECT DISTINCT pdc.precon_deck_id AS deck_id,
                      magic_cards.scryfall_oracle_id::text AS oracle_id
      FROM precon_deck_cards pdc
      JOIN precon_decks pd ON pd.id = pdc.precon_deck_id
      JOIN magic_cards ON magic_cards.id = pdc.magic_card_id
      WHERE pd.deck_type = '#{DECK_TYPE}'
        AND pdc.board_type IN (#{QUOTED_BOARD_TYPES})
        AND magic_cards.is_token = false
        AND magic_cards.scryfall_oracle_id IS NOT NULL
    SQL

    def self.total_decks
      PreconDeck.where(deck_type: DECK_TYPE).count
    end
  end
end
