#
# reorders the grouped relation Search::Collection builds for the collections table
#
# The relation arrives already ordered by owned price and already grouped by magic_cards.id,
# with the quantity/foil_quantity aggregate aliases the table view reads. We only ever swap
# the ORDER BY - dropping the select or the grouping would blank out the price columns and
# silently disable CollectionQuery::Filter#exclude_proxy_only.
#
module CollectionQuery
  class CollectionSort < Service
    # the default: leave Search::Collection's owned-price ordering alone
    DEFAULT_COLUMN = 'owned_price'.freeze

    # card_number is a string ("12a", "T5"), so pull the digits out to sort numerically and
    # push the ones with no digits to the end. Aliased into the SELECT rather than dropped
    # straight into ORDER BY - the color filter can add DISTINCT, and Postgres then requires
    # ORDER BY expressions to appear in the select list.
    CARD_NUMBER_SQL = "NULLIF(REGEXP_REPLACE(magic_cards.card_number, '\\D', '', 'g'), '')::integer".freeze

    def initialize(cards:, column: nil, direction: nil)
      @cards = cards
      @column = column.to_s
      @direction = direction.to_s == 'desc' ? 'desc' : 'asc'
    end

    def call
      # deterministic tiebreak so pagination doesn't shuffle tied rows between pages
      sorted.order('magic_cards.id' => :asc)
    end

    private

    def sorted
      case @column
      when '', DEFAULT_COLUMN then @cards
      when 'card_number' then sort_by_card_number
      else sort_by_column
      end
    end

    def sort_by_card_number
      direction = @direction == 'desc' ? 'DESC' : 'ASC'

      @cards
        .reorder(nil)
        .select("#{CARD_NUMBER_SQL} AS card_number_numeric")
        .order(Arel.sql("card_number_numeric #{direction} NULLS LAST"), 'magic_cards.card_number' => @direction)
    end

    # ColumnSort drops an unrecognized column silently, which would leave us with no ORDER BY
    # at all once we've reordered, so keep the owned-price ordering instead
    def sort_by_column
      return @cards unless ColumnSort::ALLOWED_COLUMNS.include?(@column)

      ColumnSort.call(
        records: @cards.reorder(nil), column: @column, direction: @direction, table_name: 'magic_cards'
      )
    end
  end
end
