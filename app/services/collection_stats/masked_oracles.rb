module CollectionStats
  # The `masked` CTE: every owned oracle id tagged with its colour identity as a 5-bit mask.
  #
  # Shared by BuildableProfile (roles per mask) and BuildableTribes (creature types per mask) so the
  # two cannot disagree about which bucket a card belongs to. Written against `owned_by_oracle`, so
  # any statement including it has to declare that CTE first - see Base#owned_oracles.
  module MaskedOracles
    # Basics are tagged manabase like any other land, and "you own a Forest" is not information.
    # Distinct counting already caps their contribution at 5, but they are dropped for the same
    # reason CardAnalysis::CommanderSynergy drops them: they are never the answer to anything.
    EXCLUDED_NAMES = DeckRules::Evaluators::Base::BASIC_LAND_NAMES

    private

    # BIT_OR over every owned printing rather than a representative one: identity is a property of
    # the card, so all its printings agree, and letting them all aggregate avoids a MAX(id) subquery
    # to pick a winner.
    #
    # LEFT JOIN on both colour hops so colourless cards survive with mask 0 - they have no
    # magic_card_color_idents rows at all, and they are legal in every deck.
    def masked_sql
      <<~SQL.squish
        SELECT owned_by_oracle.scryfall_oracle_id AS scryfall_oracle_id,
               #{Commanders::ColorMask::IDENTITY_MASK} AS mask
        FROM owned_by_oracle
        JOIN magic_cards ON magic_cards.scryfall_oracle_id::text = owned_by_oracle.scryfall_oracle_id
        LEFT JOIN magic_card_color_idents ON magic_card_color_idents.magic_card_id = magic_cards.id
        LEFT JOIN colors ON colors.id = magic_card_color_idents.color_id
        WHERE magic_cards.name NOT IN (#{quoted_excluded})
        GROUP BY owned_by_oracle.scryfall_oracle_id
      SQL
    end

    def masked_oracles
      owned_oracles
        .with(masked: Arel.sql(masked_sql))
        .joins('JOIN masked ON masked.scryfall_oracle_id = owned_by_oracle.scryfall_oracle_id')
    end

    def quoted_excluded
      EXCLUDED_NAMES.map { |name| MagicCard.connection.quote(name) }.join(', ')
    end
  end
end
