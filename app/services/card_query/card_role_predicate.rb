#
# builds the WHERE fragment for a `role:` or `effect:` term
#
# card_roles has no magic_card_id - it hangs off scryfall_oracle_id - so this cannot use Builder's
# shared assoc subquery, which joins on magic_card_id.
#
# The cast sits on the magic_cards side (uuid) rather than the card_roles side (string) on purpose:
# casting the card_roles column would make index_card_roles_on_scryfall_oracle_id unusable and turn
# every role lookup into a sequential scan. CollectionStats::Base documents the same trade.
#
# Gated at HIGH_CONFIDENCE because a search result is a claim that the card does the thing, and below
# that threshold the pattern rules are guessing.
#
# Returns an array ready to splat into `where`: [sql, *binds]. The column name comes from
# FieldRegistry and is never user input; the value is always bound.
#
module CardQuery
  class CardRolePredicate < Service
    def initialize(column:, value:)
      @column = column
      @value = value
    end

    def call
      [
        "magic_cards.scryfall_oracle_id::text IN (
           SELECT card_roles.scryfall_oracle_id FROM card_roles
           WHERE card_roles.#{@column} = ? AND card_roles.confidence >= ?
         )".squish,
        normalized_value,
        CardRole::HIGH_CONFIDENCE
      ]
    end

    private

    # Roles and effects are stored snake_cased, but nobody types "mana_rock" into a search bar when
    # "mana rock" reads the same.
    def normalized_value
      @value.to_s.downcase.tr(' -', '__')
    end
  end
end
