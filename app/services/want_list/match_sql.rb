# The want x copy join behind WantList::Matches, as a `pairs` CTE: one row per want_list_items row
# per collection_magic_cards row that would satisfy it.
#
# Two branches glued with UNION ALL rather than one join with an OR in it. An OR across
# `magic_card_id = ...` and `scryfall_oracle_id = ...` leaves the planner nothing to drive an index
# with and it falls back to hashing every copy in the table; split, the exact branch walks
# index_collection_magic_cards_on_magic_card_id and the oracle branch goes through
# index_magic_cards_on_scryfall_oracle_id_and_card_side first. The branches are disjoint - an
# any-printing want with an oracle id only ever takes the oracle branch, which covers its own printing
# too - so nothing is counted twice.
#
# The match rule is WantListItem.matching / WantList::List#owned_sql read from the other side. Copies
# are held on front faces, which is what the card_side filter keeps the oracle branch to.
#
# Quantities come out already cut down to the finish the want accepts, so a foil-only want reports no
# regular copies however many the holder has, and a row with nothing left after that (which is every
# proxy-only row: proxies live in their own counters) is not a match. Trade counts are zeroed for a
# holder whose trade list is private - they still own the card, but what they have marked is not
# ours to show.
module WantList
  module MatchSql
    EXACT_BRANCH = <<~SQL.squish.freeze
      FROM want_list_items wants
      INNER JOIN collection_magic_cards copies ON copies.magic_card_id = wants.magic_card_id
      INNER JOIN collections ON collections.id = copies.collection_id
      INNER JOIN users holders ON holders.id = collections.user_id
      WHERE (wants.any_printing = FALSE OR wants.scryfall_oracle_id IS NULL)
    SQL

    ORACLE_BRANCH = <<~SQL.squish.freeze
      FROM want_list_items wants
      INNER JOIN magic_cards printings ON printings.scryfall_oracle_id = wants.scryfall_oracle_id
        AND (printings.card_side IS NULL OR printings.card_side = 'a')
      INNER JOIN collection_magic_cards copies ON copies.magic_card_id = printings.id
      INNER JOIN collections ON collections.id = copies.collection_id
      INNER JOIN users holders ON holders.id = collections.user_id
      WHERE wants.any_printing = TRUE AND wants.scryfall_oracle_id IS NOT NULL
    SQL

    QUANTITY = "CASE WHEN wants.foil_preference = 'foil' THEN 0 ELSE COALESCE(copies.quantity, 0) END".freeze
    FOIL_QUANTITY =
      "CASE WHEN wants.foil_preference = 'non_foil' THEN 0 ELSE COALESCE(copies.foil_quantity, 0) END".freeze
    # %<viewer_id>d is filled in by `pairs`: the viewer's own trade marks are theirs to see either way
    TRADE_QUANTITY = <<~SQL.squish.freeze
      CASE WHEN wants.foil_preference = 'foil'
             OR (holders.trades_public = FALSE AND holders.id <> %<viewer_id>d) THEN 0
           ELSE copies.trade_quantity END
    SQL
    TRADE_FOIL_QUANTITY = <<~SQL.squish.freeze
      CASE WHEN wants.foil_preference = 'non_foil'
             OR (holders.trades_public = FALSE AND holders.id <> %<viewer_id>d) THEN 0
           ELSE copies.trade_foil_quantity END
    SQL

    COLUMNS = <<~SQL.squish.freeze
      SELECT wants.id AS want_id, wants.user_id AS wanter_id, collections.user_id AS holder_id,
             copies.magic_card_id AS printing_id,
             #{QUANTITY} AS quantity, #{FOIL_QUANTITY} AS foil_quantity,
             #{TRADE_QUANTITY} AS trade_quantity, #{TRADE_FOIL_QUANTITY} AS trade_foil_quantity
    SQL

    # never a user's own copies, never a private collection, never a deck slot that is only planned
    COMMON = <<~SQL.squish.freeze
      AND copies.staged = FALSE AND copies.needed = FALSE
      AND collections.is_public = TRUE
      AND collections.user_id <> wants.user_id
      AND (#{QUANTITY}) + (#{FOIL_QUANTITY}) > 0
    SQL

    # `conditions` is appended to both branches, so it may only name wants, copies, collections and
    # holders. It has to arrive already sanitized.
    def self.pairs(conditions, viewer_id:)
      columns = format(COLUMNS, viewer_id: viewer_id)

      <<~SQL.squish
        WITH pairs AS (
          #{columns} #{EXACT_BRANCH} #{COMMON} #{conditions}
          UNION ALL
          #{columns} #{ORACLE_BRANCH} #{COMMON} #{conditions}
        )
      SQL
    end
  end
end
