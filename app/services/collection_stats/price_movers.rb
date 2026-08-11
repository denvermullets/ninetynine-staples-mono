# What moved this week, gainers and losers in one list.
#
# One list rather than two. A collection's week is a single story - the $40 a card gave back
# matters exactly as much as the $40 another one picked up - so the ranking is on ABS(delta) and
# the direction is carried by colour instead of by which table a row landed in.
#
# The ORDER BY repeats the delta expression rather than referencing the SELECT alias, per the
# house rule from CollectionQuery::CollectionSort.
#
# Sql::WEEKLY_DELTA prices real copies only, so proxies are already excluded from the move; the
# copies and value columns here use REAL_QTY/REAL_VALUE to match. Showing a card's 12 total
# copies next to a dollar move earned by the 2 real ones would be a lie about where the money
# came from.
#
# Rows whose move rounds to nothing are dropped rather than ranked last: price_change_weekly_* is
# a percentage on a price with two decimal places, so a cent-priced bulk common can carry a
# non-zero percentage that is worth $0.00 to you.
module CollectionStats
  class PriceMovers < Base
    TOP = 10
    GAIN_CLASS = 'text-accent-50'.freeze
    LOSS_CLASS = 'text-accent-100'.freeze

    COLUMNS = [
      'magic_cards.id', 'magic_cards.name', 'magic_cards.image_small', 'magic_cards.image_large',
      'boxsets.name', 'boxsets.keyrune_code', REAL_QTY, REAL_VALUE, Sql::WEEKLY_DELTA
    ].freeze

    def call
      return [] if no_collections?

      fetch.map { |row| build_row(row) }
    end

    private

    def fetch
      owned_cards
        .left_joins(:boxset)
        .where(Arel.sql("ROUND((#{Sql::WEEKLY_DELTA})::numeric, 2) <> 0"))
        .order(Arel.sql("ABS(#{Sql::WEEKLY_DELTA}) DESC, magic_cards.id ASC"))
        .limit(TOP)
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
    end

    def build_row(row)
      id, name, image, image_large, set_name, keyrune, copies, value, delta = row
      delta = to_money(delta || 0)

      { id: id, name: name || 'Unknown card', set_name: set_name, icon: keyrune_icon(keyrune),
        image: image, image_large: image_large || image, copies: copies.to_i,
        value: to_money(value || 0), delta: delta, percent: percent(to_money(value || 0), delta),
        delta_class: delta.negative? ? LOSS_CLASS : GAIN_CLASS }
    end

    # the move as a percentage of what the copies were worth a week ago, recovered from the two
    # numbers already in hand rather than by re-reading price_change_weekly_* - a card held in
    # both finishes has two of those percentages and no single one of them is the card's move
    def percent(value, delta)
      share(delta, value - delta)
    end
  end
end
