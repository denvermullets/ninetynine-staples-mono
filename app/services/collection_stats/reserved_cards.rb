# Every Reserved List printing, measured against everything the viewer owns.
#
# The Reserved List is 571 cards and 1,477 printings, which is small enough that this does not need
# the machinery a set page does: one scan, everything folded in Ruby, no index on is_reserved.
#
# Two units, the same split the set page makes and for the same reason: the grid is a wall of art you
# scroll for the ones that are greyed, so a row there is a PRINTING - the Beta dual and the Revised
# one are two different objects to want. The table is a list of cards you either have or do not, so a
# row there is a CARD and its printings live inside the expansion.
#
# Unlike the set grid these are printings rather than finish slots. Splitting each one into a regular
# and a foil slot would nearly double a list where most cards predate foils entirely, so the foil is
# reported as a chip the way the set table reports missing_foil and it never moves the numbers.
#
# REAL_COPIES rides on the join, so a printing held only as a proxy comes back as a null and reads as
# one you do not have - the same rule the set pages and the completion panel use, because a proxy is
# the thing you print BECAUSE you have not acquired it.
module CollectionStats
  class ReservedCards < Base
    include SetBasis

    FILTERS = %w[all owned missing].freeze

    SORTS = %w[name price set].freeze

    UNITS = %w[card printing].freeze

    PRIMARY_SET_TYPES = %w[core expansion].freeze

    # a printing whose set has no release date sorts last rather than winning by being null
    FAR_FUTURE = Date.new(9999, 1, 1).freeze

    # Money first when sorting by price - the dual lands are the question this page gets opened to
    # answer. Set order is newest-first so the reprint sets group at the top rather than burying the
    # 1993 originals under them.
    ORDERS = {
      'name' => 'magic_cards.name ASC, boxsets.release_date ASC',
      'price' => "#{Sql::COPY_PRICE} DESC NULLS LAST, magic_cards.name ASC",
      'set' => 'boxsets.release_date DESC NULLS LAST, magic_cards.name ASC'
    }.freeze

    COLUMNS = [
      'magic_cards.id', 'magic_cards.name', 'magic_cards.card_number', 'magic_cards.rarity',
      'magic_cards.card_type', 'magic_cards.mana_cost', 'magic_cards.edhrec_saltiness',
      'magic_cards.normal_price', 'magic_cards.foil_price',
      'magic_cards.price_change_weekly_normal', 'magic_cards.price_change_weekly_foil',
      'magic_cards.image_medium', 'magic_cards.image_large',
      'magic_cards.scryfall_oracle_id::text',
      'boxsets.code', 'boxsets.name', 'boxsets.keyrune_code', 'boxsets.release_date',
      'boxsets.set_type',
      Sql::COPY_PRICE, FOIL_AVAILABLE,
      'COALESCE(owned.qty, 0)', 'COALESCE(owned.foil_qty, 0)'
    ].freeze

    # One name per COLUMNS entry, in the same order. Keep them in step.
    KEYS = %i[
      id name number rarity card_type mana_cost salt normal_price foil_price
      change_normal change_foil image image_large oracle_id
      set_code set_name keyrune_code released set_type
      price foil_available qty foil_qty
    ].freeze

    def initialize(collection_ids:, filter: 'all', sort: 'name', unit: 'printing')
      super(collection_ids: collection_ids)
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : 'all'
      @sort = SORTS.include?(sort.to_s) ? sort.to_s : 'name'
      @unit = UNITS.include?(unit.to_s) ? unit.to_s : 'printing'
    end

    # Counts follow the unit, because the thing being counted moves with it - the filter toggle says
    # which. Totals do NOT: they are the header, they are about the whole list, and a completion
    # figure that changed when you clicked Table would be reporting on the view instead of the
    # collection. So they are always taken off the printings, before any folding or filtering.
    def call
      printings = fetch.map { |row| printing(row) }
      rows = @unit == 'card' ? group(printings) : printings

      { rows: rows.select { |row| keep?(row) }, counts: counts(rows), totals: totals(printings) }
    end

    private

    def fetch
      MagicCard
        .with(owned: owned_rows)
        .joins(:boxset)
        .joins("LEFT JOIN owned ON owned.magic_card_id = magic_cards.id AND #{REAL_COPIES}")
        .where(is_reserved: true, is_token: false)
        .where(PRINTABLE)
        .order(Arel.sql(ORDERS[@sort]))
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
    end

    # Zipped rather than destructured: the row is twenty-two wide, and a positional unpacking that
    # long is one inserted column away from silently shifting every field after it. KEYS sits
    # directly under COLUMNS so the two are read as the pair they are.
    def printing(row)
      fields = KEYS.zip(row).to_h

      fields.merge(image_large: fields[:image_large].presence || fields[:image],
                   keyrune: keyrune_icon(fields[:keyrune_code]))
            .merge(copies(fields[:qty].to_i, fields[:foil_qty].to_i, fields[:foil_available]))
    end

    def group(printings)
      printings.group_by { |row| key_for(row) }.map { |key, rows| card_row(key, rows) }
    end

    # The ORIGINAL printing names and prices the row, whichever way the list is sorted - a Gaea's
    # Cradle row that said "Urza's Saga" under name order and "30th Anniversary" under price order
    # would be two different-looking rows for the same card. Groups still come out in sort order;
    # only which printing speaks for the card is pinned.
    def card_row(key, printings)
      primary = primary_of(printings)
      owned = printings.count { |row| row[:owned] }

      { key: key, name: primary[:name], primary: primary, printings: printings,
        owned_printings: owned, total_printings: printings.size,
        owned_qty: printings.sum { |row| row[:qty] },
        owned_foil_qty: printings.sum { |row| row[:foil_qty] },
        owned: owned.positive?, incomplete: owned < printings.size,
        missing_foils: printings.count { |row| row[:missing_foil] } }
    end

    def copies(qty, foil_qty, foil_available)
      owned = (qty + foil_qty).positive?
      foil_available = foil_available ? true : false

      { qty: qty, foil_qty: foil_qty, copies: qty + foil_qty, owned: owned, incomplete: !owned,
        foil_available: foil_available, missing_foil: foil_available && foil_qty.zero? }
    end

    # Owned and missing are not opposites at card unit, and that is deliberate - the same rule
    # SetCards follows. A card is owned if ANY printing is, and missing if ANY printing is not, so a
    # Mox Diamond at 1 of 3 is a card you have AND one you are still shopping for. At printing unit
    # the two collapse back into opposites, because a printing is one object.
    def keep?(row)
      case @filter
      when 'owned' then row[:owned]
      when 'missing' then row[:incomplete]
      else true
      end
    end

    def counts(rows)
      { all: rows.size,
        owned: rows.count { |row| row[:owned] },
        missing: rows.count { |row| row[:incomplete] } }
    end

    # Both units, because on their own each one lies. 55 of 1,477 printings reads as a collection
    # that owns nothing, when it may be 42 of the 571 CARDS - nobody is chasing all seven printings
    # of an Underground Sea, so the card figure is the one a collector means by "how far along am I".
    # The printing figure is what the grid below actually shows, so it has to be on the page too.
    def totals(rows)
      cards = rows.group_by { |row| key_for(row) }.values
      owned_cards = cards.count { |group| group.any? { |row| row[:owned] } }

      { printings_total: rows.size,
        printings_owned: rows.count { |row| row[:owned] },
        cards_total: cards.size,
        cards_owned: owned_cards,
        cards_share: share(owned_cards, cards.size) }
        .merge(money(rows, cards))
    end

    def money(rows, cards)
      { value_owned: to_money(rows.sum { |row| owned_value(row) }),
        cost_to_complete: to_money(cards.sum { |group| completion_cost(group) }) }
    end

    # Earliest release, but only among sets a card was actually PRINTED in. Straight min_by on the
    # date picks memorabilia: Abeyance's oversized league prize predates Weatherlight by ten days, so
    # the row would name an oversized promo as the original printing of the card. Everything on the
    # Reserved List debuted in a core or expansion set, so preferring those recovers the real one,
    # and the fallback keeps a card whose only rows are promos from losing its primary entirely.
    def primary_of(printings)
      candidates = printings.select { |row| PRIMARY_SET_TYPES.include?(row[:set_type]) }

      (candidates.presence || printings).min_by { |row| [row[:released] || FAR_FUTURE, row[:id]] }
    end

    # Same fallback chain SetCards uses: a printing with no oracle id is its own card rather than
    # silently merging with every other null.
    def key_for(row)
      return "oracle:#{row[:oracle_id]}" if row[:oracle_id].present?
      return "name:#{row[:name]}" if row[:name].present?

      "id:#{row[:id]}"
    end

    def owned_value(row)
      (row[:qty] * row[:normal_price].to_d) + (row[:foil_qty] * row[:foil_price].to_d)
    end

    # The cheapest printing of a card you hold none of. A card you already have costs nothing to
    # finish - this is what the list would cost to COMPLETE, not what it would cost to buy twice -
    # and printings with no price yet are skipped rather than counted as free.
    def completion_cost(group)
      return 0 if group.any? { |row| row[:owned] }

      prices = group.map { |row| row[:price].to_d }.select(&:positive?)

      prices.min || 0
    end
  end
end
