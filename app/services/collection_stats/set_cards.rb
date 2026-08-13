# Every card in one set, folded so that a card is a card and not a pile of printings.
#
# The boxset browser lists printings, which is correct when you are looking up a price and wrong when
# you are asking what you still need: Bloomburrow's 397 rows are 281 cards, and a showcase Agate
# Assault sitting eight screens away from the normal one makes "do I have this" a scrolling exercise.
# So printings are grouped under the card they are printings OF and the variants become sub-rows.
#
# The grouping key is scryfall_oracle_id. Within one set every printing of a card carries the same
# one, which makes it exactly the right key and means none of magic_card_variations, frame_effects or
# name-matching has to be dragged in to work out what belongs with what. Printings with no oracle id
# fall back to the name, and then to their own id, so an unbackfilled row is its own group rather
# than silently merging with every other null.
#
# One query, then Ruby. Grouping in SQL would mean array_agg over a wider GROUP BY to carry each
# printing's own columns out, and the set is bounded - a few hundred rows, a couple of thousand for
# Secret Lair - so there is nothing to win and a lot of legibility to lose.
#
# REAL_COPIES rides on the join, so a printing held only as a proxy comes back as a null and reads
# as one you do not have. Consistent with the panel, and the point of the missing filter.
module CollectionStats
  class SetCards < Base
    include SetBasis

    FILTERS = %w[all owned missing].freeze

    COLUMNS = [
      'magic_cards.id', 'magic_cards.name', 'magic_cards.card_number', CARD_NUMBER_INT,
      'magic_cards.rarity', 'magic_cards.mana_cost', 'magic_cards.card_type',
      'magic_cards.normal_price', 'magic_cards.foil_price',
      'magic_cards.price_change_weekly_normal', 'magic_cards.price_change_weekly_foil',
      'magic_cards.edhrec_saltiness', 'magic_cards.scryfall_oracle_id::text',
      'magic_cards.image_medium', 'magic_cards.image_large',
      IN_BASE, 'COALESCE(owned.qty, 0)', 'COALESCE(owned.foil_qty, 0)'
    ].freeze

    def initialize(collection_ids:, boxset:, filter: 'all')
      super(collection_ids: collection_ids)
      @boxset = boxset
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : 'all'
    end

    def call
      groups = group(fetch.map { |row| printing(row) })

      { rows: groups.select { |group| keep?(group) }, counts: counts(groups) }
    end

    private

    # ORDER BY in the query rather than sort_by afterwards: the rows come out in set order, so
    # group_by hands back the groups in that order too and the lowest-numbered printing of each card
    # is the one at the front of its list.
    def fetch
      MagicCard
        .with(owned: owned_rows)
        .joins(:boxset)
        .joins("LEFT JOIN owned ON owned.magic_card_id = magic_cards.id AND #{REAL_COPIES}")
        .where(boxset_id: @boxset.id, is_token: false)
        .where(PRINTABLE)
        .order(Arel.sql("#{CARD_NUMBER_INT} ASC NULLS LAST, magic_cards.id ASC"))
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
    end

    def printing(row)
      id, name, number, sort_number, rarity, mana_cost, card_type, normal_price, foil_price,
        change_normal, change_foil, salt, oracle_id, image, image_large, in_base, qty, foil_qty = row

      { id: id, name: name, number: number, sort_number: sort_number, rarity: rarity,
        mana_cost: mana_cost, card_type: card_type, normal_price: normal_price,
        foil_price: foil_price, change_normal: change_normal, change_foil: change_foil,
        salt: salt, oracle_id: oracle_id, image: image,
        image_large: image_large.presence || image, in_base: in_base ? true : false,
        qty: qty.to_i, foil_qty: foil_qty.to_i, owned: (qty.to_i + foil_qty.to_i).positive? }
    end

    def group(printings)
      printings.group_by { |row| key_for(row) }.map { |key, rows| card_row(key, rows) }
    end

    def key_for(row)
      return "oracle:#{row[:oracle_id]}" if row[:oracle_id].present?
      return "name:#{row[:name]}" if row[:name].present?

      "id:#{row[:id]}"
    end

    # The base-run printing is the card as the set numbers it, so it names the row and prices it even
    # when a borderless version sorts first on a set whose base printing has no digits in its number.
    def card_row(key, printings)
      primary = printings.find { |row| row[:in_base] } || printings.first
      owned = printings.count { |row| row[:owned] }

      { key: key, name: primary[:name], primary: primary, printings: printings,
        owned_printings: owned, total_printings: printings.size,
        owned_qty: printings.sum { |row| row[:qty] },
        owned_foil_qty: printings.sum { |row| row[:foil_qty] },
        owned: owned.positive?, in_base: primary[:in_base] }
    end

    # A card counts as owned if ANY of its printings is. Somebody who has the normal Agate Assault
    # and not the showcase one has the card; the 1/3 in the printings column is where that shows,
    # not in a missing list they have already dealt with.
    def keep?(group)
      case @filter
      when 'owned' then group[:owned]
      when 'missing' then !group[:owned]
      else true
      end
    end

    # Counted off every group rather than off the filtered list, so the toggle can label all three
    # of its buttons from the one pass the page already paid for.
    def counts(groups)
      owned = groups.count { |group| group[:owned] }

      { all: groups.size, owned: owned, missing: groups.size - owned }
    end
  end
end
