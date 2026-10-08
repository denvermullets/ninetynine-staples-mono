# Every card you own that Card Kingdom is buying, as a pull list - the sell-side companion to
# MoversTable. Unlike the movers there is no movement rule: a card whose price sat still all week
# is just as sellable as one that jumped.
#
# One row per printing AND finish, not per printing. CK prices the finishes separately and you pull
# them separately, so a non-foil it pays $0.10 for and the foil it pays $2 for are two rows, each
# with its own copies and payout. A finish you hold none of, or that CK is not buying (a buylist of
# 0 or NULL), makes no row.
#
# Real copies only, matching every other money figure: nobody buys a proxy.
#
# `payment` is cash or store credit. CK adds CREDIT_BONUS on top of the cash price when you take
# credit, so credit multiplies the unit price before anything else reads it - the buylist range,
# the sort and the payout are all in whatever you are being paid in, so "min $1" in credit means
# $1 of credit. The unit is rounded to the cent first and the payout is copies x that rounded unit,
# so a row's numbers multiply out on screen.
#
# `decks` decides whether copies sitting in a deck count. The default leaves decks out - a card
# sleeved in a deck is rarely one you mean to sell - by narrowing the collection ids before the
# copies are summed, so a card held in a binder and a deck offers only the binder's copies.
#
# The database does the part that scales with the collection: one grouped query that sums the real
# copies per printing and drops what CK is not buying, through hash conditions and fixed SQL text
# only - nothing a caller passes is ever part of a SQL string. The credit maths, the buylist range,
# the sort and the paging run in Ruby over those small rows, and only the page being shown loads its
# set, images and where the copies sit.
module CollectionStats
  class SellList < Base
    PER_PAGE = 50

    # what Card Kingdom adds to the cash price when you take store credit
    CREDIT_BONUS = BigDecimal('0.3')

    PAYMENTS = %w[cash credit].freeze
    FINISHES = %w[both normal foil].freeze
    DECKS = %w[skip include].freeze
    SORTS = %w[payout buylist copies price rarity name].freeze
    SORT_DIRS = %w[desc asc].freeze
    AMOUNTS = %i[min_buylist max_buylist].freeze
    RARITIES = MoversTable::RARITIES
    RARITY_RANKS = MoversTable::RARITY_RANKS

    # name reads A-Z; every other key reads biggest first
    DEFAULT_DIRS = Hash.new('desc').merge('name' => 'asc').freeze

    # CK is buying at least one finish of the printing
    BUYING = 'magic_cards.ck_buylist_normal_price > 0 OR magic_cards.ck_buylist_foil_price > 0'.freeze

    # the per-printing columns the grouped query reads, in pluck order
    HOLDING_COLUMNS = [
      'magic_cards.id', 'magic_cards.name', 'magic_cards.rarity',
      'magic_cards.normal_price', 'magic_cards.foil_price',
      'magic_cards.ck_buylist_normal_price', 'magic_cards.ck_buylist_foil_price',
      'SUM(collection_magic_cards.quantity)', 'SUM(collection_magic_cards.foil_quantity)'
    ].freeze

    def initialize(collection_ids:, filters: {}, page: 1, per_page: PER_PAGE)
      @filters = normalise(filters.to_h.with_indifferent_access)
      super(collection_ids: selling_from(collection_ids))
      @page = [page.to_i, 1].max
      @per_page = per_page.to_i.clamp(1, 100)
    end

    def call
      rows = no_collections? ? [] : sorted(offers)
      page = rows.slice((@page - 1) * @per_page, @per_page) || []

      { rows: decorate(page), total: rows.size, copies: rows.sum { |row| row[:copies] },
        payout: to_money(rows.sum(BigDecimal(0)) { |row| row[:payout] }),
        page: @page, per_page: @per_page, filters: @filters }
    end

    private

    def normalise(raw)
      sort = pick(raw[:sort], SORTS)

      { payment: pick(raw[:payment], PAYMENTS), finish: pick(raw[:finish], FINISHES),
        decks: pick(raw[:decks], DECKS), **AMOUNTS.index_with { |key| amount(raw[key]) },
        rarity: RARITIES & Array(raw[:rarity]).map(&:to_s),
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

    def selling_from(collection_ids)
      ids = Array(collection_ids).compact
      return ids if @filters[:decks] == 'include' || ids.empty?

      Collection.where(id: ids).where.not(id: Collection.decks).pluck(:id)
    end

    def multiplier
      @filters[:payment] == 'credit' ? 1 + CREDIT_BONUS : BigDecimal(1)
    end

    # one row per printing CK buys in at least one finish, with the real copies summed across the
    # collections in scope
    def holdings
      scope = CollectionMagicCard.joins(:magic_card)
                                 .where(collection_id: @collection_ids, staged: false, needed: false)
                                 .where(BUYING)
      scope = scope.where(magic_cards: { rarity: @filters[:rarity] }) if @filters[:rarity].any?

      scope.group('magic_cards.id').pluck(*HOLDING_COLUMNS.map { |column| Arel.sql(column) })
    end

    # the holdings unpivoted into one offer per finish held that CK is buying, inside the range
    def offers
      holdings.flat_map do |holding|
        id, name, rarity, normal_price, foil_price, buylist_normal, buylist_foil, qty, foil_qty = holding
        card = { id: id, name: name, rarity: rarity }

        [offer(card, 'normal', qty, buylist_normal, normal_price),
         offer(card, 'foil', foil_qty, buylist_foil, foil_price)].compact
      end
    end

    def offer(card, finish, copies, buylist, price)
      return unless ['both', finish].include?(@filters[:finish])
      return unless copies.to_i.positive? && buylist.to_d.positive?

      unit = (buylist.to_d * multiplier).round(2)
      return unless in_range?(unit)

      card.merge(finish: finish, copies: copies.to_i, buylist: unit, payout: unit * copies.to_i,
                 price: to_money(price || 0))
    end

    def in_range?(unit)
      (@filters[:min_buylist].nil? || unit >= @filters[:min_buylist]) &&
        (@filters[:max_buylist].nil? || unit <= @filters[:max_buylist])
    end

    # The sort key decides, reversed for desc. A printing with no rarity sorts last either way, as on
    # the movers page. Ties break on the printing and then its finish, so a page boundary never
    # shuffles a row between two pages.
    def sorted(rows)
      rows.sort do |a, b|
        compare_keys(sort_key(a), sort_key(b)).nonzero? || ([a[:id], a[:finish]] <=> [b[:id], b[:finish]])
      end
    end

    def compare_keys(left, right)
      return (left.nil? ? 1 : 0) <=> (right.nil? ? 1 : 0) if left.nil? || right.nil?

      @filters[:dir] == 'desc' ? right <=> left : left <=> right
    end

    def sort_key(row)
      case @filters[:sort]
      when 'buylist' then row[:buylist]
      when 'copies' then row[:copies]
      when 'price' then row[:price]
      when 'rarity' then RARITY_RANKS[row[:rarity]]
      when 'name' then row[:name].to_s.downcase
      else row[:payout]
      end
    end

    # the page's set, images and places - loaded for these rows only
    def decorate(rows)
      return [] if rows.empty?

      ids = rows.pluck(:id).uniq
      cards = MagicCard.includes(:boxset).where(id: ids).index_by(&:id)
      places = places_for(ids)

      rows.map { |row| decorate_row(row, cards.fetch(row[:id]), places) }
    end

    def decorate_row(row, card, places)
      row.merge(name: row[:name] || 'Unknown card', set_name: card.boxset&.name,
                icon: keyrune_icon(card.boxset&.keyrune_code), image: card.image_small,
                image_large: card.image_large || card.image_small, payout: to_money(row[:payout]),
                places: places.fetch([row[:id], row[:finish]], []))
    end

    # Where each row's copies sit, so the list can be pulled binder by binder:
    # { [magic_card_id, finish] => [{ name:, copies: }, ...] }, collections in name order
    def places_for(card_ids)
      CollectionMagicCard.joins(:collection)
                         .where(collection_id: @collection_ids, magic_card_id: card_ids, staged: false, needed: false)
                         .order('collections.name')
                         .pluck(:magic_card_id, 'collections.name', :quantity, :foil_quantity)
                         .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(id, name, qty, foil), places|
        places[[id, 'normal']] << { name: name, copies: qty } if qty.to_i.positive?
        places[[id, 'foil']] << { name: name, copies: foil } if foil.to_i.positive?
      end
    end
  end
end
