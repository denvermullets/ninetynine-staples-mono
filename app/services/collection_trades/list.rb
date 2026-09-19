# Every copy a user has marked for trade across their public collections, as the collections table
# pipeline sees it.
#
# The rows come out of Collections::CardSearch with tradeable: true, so search, sort and PageRows all
# work exactly as they do on the collections page - one row per printing, with the trade_quantity /
# trade_foil_quantity aggregates summed across every public collection holding it.
#
# Copies marked in a private collection are left out for the owner too. The list is what a trade
# partner is offered, and showing the owner cards nobody else can see would make it lie about that.
module CollectionTrades
  class List < Service
    FINISHES = %w[all regular foil].freeze

    # value is CollectionSort's owned-price default, which on a tradeable-only base is the price of the
    # highest finish on offer
    SORTS = {
      'value' => { column: CollectionQuery::CollectionSort::DEFAULT_COLUMN, direction: 'desc' },
      'name' => { column: 'name', direction: 'asc' },
      'mana' => { column: 'mana_value', direction: 'asc' }
    }.freeze

    SortChoice = Data.define(:column, :direction)

    def initialize(user:, viewer: nil, search: nil, finish: 'all', sort: 'value')
      @user = user
      @viewer = viewer
      @search = search
      @finish = FINISHES.include?(finish) ? finish : 'all'
      @sort = SORTS.key?(sort) ? sort : 'value'
    end

    def call
      { cards: cards, counts: counts, totals: totals }
    end

    private

    def cards
      searched = Collections::CardSearch.call(
        user: @user, current_user: @viewer, params: { search: @search },
        sort_config: SortChoice.new(**SORTS[@sort]), tradeable: true
      )[:cards]

      by_finish(searched)
    end

    # HAVING on the summed aggregates rather than WHERE on the rows: a printing offered as a regular
    # copy in one binder and a foil in another is one row, and a row-level filter would drop half of
    # its counts from the quantities shown next to it
    def by_finish(cards)
      case @finish
      when 'regular' then cards.having("#{::Search::Collection::TRADE_QUANTITY_SQL} > 0")
      when 'foil' then cards.having("#{::Search::Collection::TRADE_FOIL_QUANTITY_SQL} > 0")
      else cards
      end
    end

    def rows
      @user.tradeable_cards
    end

    # printings per finish pill, matching what the HAVING above would list with no search applied
    def counts
      all, regular, foil = rows.pick(
        Arel.sql('COUNT(DISTINCT collection_magic_cards.magic_card_id)'),
        Arel.sql('COUNT(DISTINCT CASE WHEN collection_magic_cards.trade_quantity > 0 ' \
                 'THEN collection_magic_cards.magic_card_id END)'),
        Arel.sql('COUNT(DISTINCT CASE WHEN collection_magic_cards.trade_foil_quantity > 0 ' \
                 'THEN collection_magic_cards.magic_card_id END)')
      )

      { all: all.to_i, regular: regular.to_i, foil: foil.to_i }
    end

    # The side total: TCG retail is the headline, the Card Kingdom buylist the floor. Each finish is
    # priced at its own column - a foil copy is never valued at the regular price.
    def totals
      copies, retail, buylist = rows.joins(:magic_card).pick(
        Arel.sql('SUM(collection_magic_cards.trade_quantity + collection_magic_cards.trade_foil_quantity)'),
        Arel.sql(value_sql('normal_price', 'foil_price')),
        Arel.sql(value_sql('ck_buylist_normal_price', 'ck_buylist_foil_price'))
      )

      { copies: copies.to_i, retail: retail.to_d, buylist: buylist.to_d }
    end

    def value_sql(regular_column, foil_column)
      'COALESCE(SUM(' \
        "collection_magic_cards.trade_quantity * COALESCE(magic_cards.#{regular_column}, 0) + " \
        "collection_magic_cards.trade_foil_quantity * COALESCE(magic_cards.#{foil_column}, 0)" \
        '), 0)'
    end
  end
end
