# The two "which cards" questions: where the money is, and what you are hoarding.
#
# Both lists come from ONE scan. Ranking by value and ranking by copies are the same set of rows
# read in two different orders, so a pair of ORDER BY ... LIMIT 10 queries would scan the whole
# collection twice to answer them. Two ROW_NUMBER() windows rank both ways in a single pass and
# the outer WHERE keeps any row that placed in either top ten.
#
# The windows repeat the value and quantity expressions rather than referencing the SELECT
# aliases beside them - the house rule from CollectionQuery::CollectionSort. Postgres would
# actually accept an alias inside OVER (ORDER BY ...) here, but the codebase does not have two
# rules about this, it has one.
#
# SUM(...) OVER () rides along to give the concentration line its denominator. It is evaluated
# over every row of the CTE, before the outer top-ten filter, so it is the whole collection's
# value and not the top ten's.
#
# LEFT JOIN on boxsets, unlike Sets' inner join: a card whose set went missing still belongs in
# "your most valuable card". It loses its set icon, not its row.
#
# Basic lands are held out of the copies list only. Nobody is hoarding 60 Forests on purpose, and
# left in they are the whole list - but a foil or Unfinity basic can be worth real money, so they
# stay in the value list and in the concentration denominator. Rather than filtering them out of
# the CTE, the copies window sorts them last: they still get ranked, they just never place.
module CollectionStats
  class TopCards < Base
    TOP = 10

    COLUMNS = %i[id name image_small image_large rarity set_name keyrune_code copies value
                 basic_land value_rank copies_rank collection_value].freeze

    # a supertype, not a name: matching on names would miss Snow-Covered Forest and every
    # non-English printing. EXISTS rather than a join because a card carries several supertypes
    # (Snow-Covered Forest is both Basic and Snow) and a join would duplicate its row.
    BASIC_LAND = <<~SQL.squish.freeze
      EXISTS (
        SELECT 1 FROM magic_card_super_types
        JOIN super_types ON super_types.id = magic_card_super_types.super_type_id
        WHERE magic_card_super_types.magic_card_id = magic_cards.id
          AND super_types.name = 'Basic'
      )
    SQL

    RANKED = <<~SQL.squish.freeze
      SELECT magic_cards.id AS id,
             magic_cards.name AS name,
             magic_cards.image_small AS image_small,
             magic_cards.image_large AS image_large,
             magic_cards.rarity AS rarity,
             boxsets.name AS set_name,
             boxsets.keyrune_code AS keyrune_code,
             #{TOTAL_QTY} AS copies,
             #{TOTAL_VALUE} AS value,
             #{BASIC_LAND} AS basic_land,
             ROW_NUMBER() OVER (ORDER BY #{TOTAL_VALUE} DESC, magic_cards.id) AS value_rank,
             ROW_NUMBER() OVER (ORDER BY #{BASIC_LAND} ASC, #{TOTAL_QTY} DESC,
                                         magic_cards.id) AS copies_rank,
             SUM(#{TOTAL_VALUE}) OVER () AS collection_value
      FROM owned
      JOIN magic_cards ON magic_cards.id = owned.magic_card_id
      LEFT JOIN boxsets ON boxsets.id = magic_cards.boxset_id
    SQL

    EMPTY = { by_value: [], by_copies: [], top_value_share: 0.0 }.freeze

    def call
      return EMPTY if no_collections?

      build(fetch)
    end

    private

    def build(rows)
      hoardable = rows.reject { |row| row[:basic_land] }
      by_value = ranked_by(rows, :value_rank).reject { |row| row[:value].zero? }
      by_copies = ranked_by(hoardable, :copies_rank).reject { |row| row[:copies].zero? }

      { by_value: by_value, by_copies: by_copies,
        top_value_share: share(by_value.sum { |row| row[:value] }, collection_value(rows)) }
    end

    # a row can place in both top tens, which is the point of fetching them together
    def ranked_by(rows, rank)
      rows.select { |row| row[rank] <= TOP }.sort_by { |row| row[rank] }.map { |row| card_row(row) }
    end

    # identical on every row - the window has no partition
    def collection_value(rows)
      rows.first&.fetch(:collection_value).to_d
    end

    def card_row(row)
      { id: row[:id], name: row[:name] || 'Unknown card', set_name: row[:set_name],
        icon: keyrune_icon(row[:keyrune_code]), image: row[:image_small],
        image_large: row[:image_large] || row[:image_small], rarity: row[:rarity],
        copies: row[:copies].to_i, value: to_money(row[:value] || 0) }
    end

    def fetch
      MagicCard
        .with(owned: owned_rows, ranked: Arel.sql(RANKED))
        .from('ranked')
        .where(Arel.sql("value_rank <= #{TOP} OR copies_rank <= #{TOP}"))
        .pluck(*COLUMNS.map { |column| Arel.sql(column.to_s) })
        .map { |row| COLUMNS.zip(row).to_h }
    end
  end
end
