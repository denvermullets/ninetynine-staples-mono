# Every card that moved, filtered however you like - the full-page version of PriceMovers.
#
# The rules are PriceMovers' rules, and its header comment is the reasoning: the dollar move is
# recovered from the percentage columns (Sql.delta), proxies carry no value so copies, value and
# move are all real copies only, rows whose move rounds to $0.00 are dropped, and ORDER BY repeats
# its expression rather than naming a SELECT alias.
#
# Every filter and sort key is whitelisted against the constants below. An unknown value falls back
# to the default; nothing a caller passes is interpolated into SQL. The numeric thresholds are
# parsed to BigDecimal and go in as bind values.
#
# The finish filter zeroes the other finish's quantity inside the expressions rather than branching
# into a second query shape: with finish=foil, the non-foil copies contribute no copies, no value and
# no move, so a card held only as a non-foil moves $0.00 and drops out on the same rule as bulk.
#
# Paging happens here rather than in the caller, so the service runs without a request: the
# movement-alert job counts `total` off the same filters a notification links to, and the number it
# states is the number the page shows. The page hands `total` to Pagy::Offset.new(count:).
module CollectionStats
  class MoversTable < Base
    PER_PAGE = 50

    WINDOWS = %w[weekly daily].freeze
    DIRECTIONS = %w[both up down].freeze
    FINISHES = %w[both normal foil].freeze
    SORTS = %w[delta percent value price name].freeze
    SORT_DIRS = %w[desc asc].freeze

    # name reads A-Z; every other key reads biggest first
    DEFAULT_DIRS = Hash.new('desc').merge('name' => 'asc').freeze

    def self.for_owner(user:, filters: {}, collection_id: nil, page: 1)
      scope = Scope.call(username: user.username, viewer: user, collection_id: collection_id)

      new(collection_ids: scope[:collection_ids], filters: filters, page: page)
    end

    def initialize(collection_ids:, filters: {}, page: 1, per_page: PER_PAGE)
      super(collection_ids: collection_ids)
      @filters = normalise(filters.to_h.with_indifferent_access)
      @page = [page.to_i, 1].max
      @per_page = per_page.to_i.clamp(1, 100)
    end

    def call
      total = no_collections? ? 0 : filtered.count
      rows = total.zero? ? [] : fetch.map { |row| build_row(row) }

      { rows: rows, total: total, page: @page, per_page: @per_page, filters: @filters }
    end

    private

    def normalise(raw)
      sort = pick(raw[:sort], SORTS)

      { window: pick(raw[:window], WINDOWS), direction: pick(raw[:direction], DIRECTIONS),
        finish: pick(raw[:finish], FINISHES), min_delta: amount(raw[:min_delta]),
        min_percent: amount(raw[:min_percent]), min_price: amount(raw[:min_price]),
        sort: sort, dir: SORT_DIRS.include?(raw[:dir].to_s) ? raw[:dir].to_s : DEFAULT_DIRS[sort] }
    end

    # the first entry of each list is its default
    def pick(value, allowed)
      allowed.include?(value.to_s) ? value.to_s : allowed.first
    end

    # a threshold of zero or less filters nothing, so it reads as no threshold at all
    def amount(value)
      number = BigDecimal(value.to_s, exception: false)
      number if number&.finite? && number.positive?
    end

    def filtered
      base = owned_cards
             .where(Arel.sql("ROUND((#{delta_sql})::numeric, 2) <> 0"))
             .where(Arel.sql(direction_sql))

      thresholds.reduce(base) do |relation, (key, sql)|
        @filters[key] ? relation.where(sql, @filters[key]) : relation
      end
    end

    # each one bound, never interpolated - the values are BigDecimal by now, but still
    def thresholds
      { min_delta: "ABS(#{delta_sql}) >= ?",
        min_percent: "ABS(#{delta_sql}) * 100 >= ? * ABS(#{old_value_sql})",
        min_price: "#{price_sql} >= ?" }
    end

    def fetch
      filtered
        .left_joins(:boxset)
        .order(Arel.sql("#{sort_sql} #{@filters[:dir].upcase} NULLS LAST, magic_cards.id ASC"))
        .limit(@per_page)
        .offset((@page - 1) * @per_page)
        .pluck(*columns.map { |column| Arel.sql(column) })
    end

    def columns
      ['magic_cards.id', 'magic_cards.name', 'magic_cards.image_small', 'magic_cards.image_large',
       'boxsets.name', 'boxsets.keyrune_code', copies_sql, value_sql, delta_sql,
       qty_sql, foil_qty_sql, 'magic_cards.normal_price', 'magic_cards.foil_price']
    end

    # the finish filter, applied by pricing the excluded finish at zero copies
    def qty_sql
      @filters[:finish] == 'foil' ? '0' : 'owned.qty'
    end

    def foil_qty_sql
      @filters[:finish] == 'normal' ? '0' : 'owned.foil_qty'
    end

    def copies_sql
      "(#{qty_sql} + #{foil_qty_sql})"
    end

    def value_sql
      "((#{qty_sql} * COALESCE(magic_cards.normal_price, 0)) " \
        "+ (#{foil_qty_sql} * COALESCE(magic_cards.foil_price, 0)))"
    end

    def delta_sql
      @delta_sql ||= Sql.holding_delta(@filters[:window].to_sym, qty: qty_sql, foil_qty: foil_qty_sql)
    end

    # what the copies were worth at the start of the window - the denominator of the move %
    def old_value_sql
      "(#{value_sql} - #{delta_sql})"
    end

    def percent_sql
      "(#{delta_sql} / NULLIF(#{old_value_sql}, 0))"
    end

    # The unit price of the dearest finish you actually hold. GREATEST skips the NULL a finish with
    # no copies yields, so a 40c non-foil you do not own cannot drag a $30 foil you do under the bar.
    def price_sql
      "GREATEST(CASE WHEN #{qty_sql} > 0 THEN magic_cards.normal_price END, " \
        "CASE WHEN #{foil_qty_sql} > 0 THEN magic_cards.foil_price END)"
    end

    def direction_sql
      case @filters[:direction]
      when 'up' then "#{delta_sql} > 0"
      when 'down' then "#{delta_sql} < 0"
      else 'TRUE'
      end
    end

    # delta and percent rank on size, like PriceMovers - a $40 drop is as big a move as a $40 rise
    def sort_sql
      case @filters[:sort]
      when 'percent' then "ABS(#{percent_sql})"
      when 'value' then value_sql
      when 'price' then price_sql
      when 'name' then 'magic_cards.name'
      else "ABS(#{delta_sql})"
      end
    end

    def build_row(row)
      id, name, image, image_large, set_name, keyrune, copies, value, delta, qty, foil_qty, *prices = row
      value = to_money(value || 0)
      delta = to_money(delta || 0)

      { id: id, name: name || 'Unknown card', set_name: set_name, icon: keyrune_icon(keyrune),
        image: image, image_large: image_large || image, copies: copies.to_i, qty: qty.to_i,
        foil_qty: foil_qty.to_i, value: value,
        delta: delta, percent: share(delta, value - delta),
        delta_class: delta.negative? ? PriceMovers::LOSS_CLASS : PriceMovers::GAIN_CLASS,
        **unit_prices(*prices) }
    end

    def unit_prices(normal_price, foil_price)
      { normal_price: to_money(normal_price || 0), foil_price: to_money(foil_price || 0) }
    end
  end
end
