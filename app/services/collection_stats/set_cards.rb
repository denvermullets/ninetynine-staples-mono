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

    FILTERS = %w[all owned missing foils].freeze

    # What one row means. The table asks about CARDS - a card you hold in the normal frame is a card
    # you have, and its showcase printing is a detail inside the row. The visual grid asks about
    # PRINTINGS, because the art is the whole reason to look at one: a grid that collapsed
    # Jin-Gitaxias' seven printings into one tile would be hiding exactly what it is there to show.
    UNITS = %w[card printing].freeze

    COLUMNS = [
      'magic_cards.id', 'magic_cards.name', 'magic_cards.card_number', CARD_NUMBER_INT,
      'magic_cards.rarity', 'magic_cards.mana_cost', 'magic_cards.card_type',
      'magic_cards.normal_price', 'magic_cards.foil_price',
      'magic_cards.price_change_weekly_normal', 'magic_cards.price_change_weekly_foil',
      'magic_cards.edhrec_saltiness', 'magic_cards.scryfall_oracle_id::text',
      'magic_cards.image_medium', 'magic_cards.image_large',
      FOIL_AVAILABLE, NONFOIL_AVAILABLE,
      IN_BASE, 'COALESCE(owned.qty, 0)', 'COALESCE(owned.foil_qty, 0)'
    ].freeze

    def initialize(collection_ids:, boxset:, filter: 'all', unit: 'card')
      super(collection_ids: collection_ids)
      @boxset = boxset
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : 'all'
      @unit = UNITS.include?(unit.to_s) ? unit.to_s : 'card'
    end

    # Same scan and the same fold either way - the only question is whether the grouping survives
    # into the rows or gets flattened back out. Both units answer `owned` off the same real-copies
    # rule, so a printing counted as owned here is one counted as owned there.
    #
    # Flattening rather than skipping the fold is what keeps a card's variants NEXT TO each other.
    # NEO numbers Jin-Gitaxias 59, 307, 371, 427, 445, 513 and 514, so a grid in plain collector
    # order scatters its seven printings over five pages - which is the one thing somebody scrolling
    # for variants cannot use. Groups come out in base-run order, so the set still reads front to
    # back and each card's variants sit with it.
    def call
      groups = group(fetch.map { |row| printing(row) })

      result(@unit == 'printing' ? slots(groups) : groups)
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

    # Split in two because the row is wide, not because the halves are different ideas: the card is
    # what the tile shows, the copies are what the badge on it says.
    def printing(row)
      id, name, number, sort_number, rarity, mana_cost, card_type, normal_price, foil_price,
        change_normal, change_foil, salt, oracle_id, image, image_large, foil_available,
        nonfoil_available, in_base, qty, foil_qty = row

      { id: id, name: name, number: number, sort_number: sort_number, rarity: rarity,
        mana_cost: mana_cost, card_type: card_type, normal_price: normal_price,
        foil_price: foil_price, change_normal: change_normal, change_foil: change_foil,
        salt: salt, oracle_id: oracle_id, image: image,
        image_large: image_large.presence || image, in_base: in_base ? true : false }
        .merge(copies(qty.to_i, foil_qty.to_i, foil_available ? true : false))
        .merge(nonfoil_available: nonfoil_available ? true : false)
    end

    # missing_foil is reported, never counted. Completion is a question about printings - you have
    # the card or you do not - and folding finishes into it would put this page's percentage at odds
    # with the completion panel's for the same set. The chip says the foil is outstanding; the bar
    # goes on measuring what SetCompletion measures.
    def copies(qty, foil_qty, foil_available)
      owned = (qty + foil_qty).positive?

      { qty: qty, foil_qty: foil_qty, owned: owned, incomplete: !owned,
        foil_available: foil_available, missing_foil: foil_available && foil_qty.zero? }
    end

    def group(printings)
      printings.group_by { |row| key_for(row) }.map { |key, rows| card_row(key, rows) }
    end

    # A SLOT is a printing in a finish - the thing you either have in the binder or do not. The grid
    # is a checklist, and a foil is its own line on it: the regular Ancestral Katana and the foil
    # Ancestral Katana are two cards to acquire, so NEO is 514 printings and a bit over a thousand
    # slots. The table stays one row per card, because that is a question about cards.
    #
    # Same picture twice, which is the honest answer - Scryfall has one scan per printing and a foil
    # is the same art. What differs is the chip, the price and whether it is greyed.
    def slots(groups)
      groups.flat_map { |group| group[:printings].flat_map { |printing| finish_slots(printing) } }
    end

    # A printing sold only in foil has no regular slot. One whose finishes were never recorded has
    # neither, and dropping it would silently shrink the set, so it falls back to a regular slot.
    def finish_slots(printing)
      slots = []
      slots << slot(printing, :regular) if printing[:nonfoil_available] || !printing[:foil_available]
      slots << slot(printing, :foil) if printing[:foil_available]
      slots
    end

    def slot(printing, finish)
      foil = finish == :foil
      copies = foil ? printing[:foil_qty] : printing[:qty]

      printing.merge(finish: finish, copies: copies, owned: copies.positive?,
                     incomplete: !copies.positive?,
                     price: foil ? printing[:foil_price] : printing[:normal_price])
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
        owned: owned.positive?, incomplete: owned < printings.size,
        missing_foils: printings.count { |row| row[:missing_foil] },
        in_base: primary[:in_base] }
    end

    def result(rows)
      { rows: rows.select { |row| keep?(row) }, counts: counts(rows) }
    end

    # Owned and missing are not opposites at card unit, and that is deliberate. A card is owned if
    # ANY of its printings is, and missing if ANY of them is not - so Jin-Gitaxias at 1 of 7 is a
    # card you have AND a card you are still shopping for, and it belongs in both lists. Filtering
    # missing down to "you own none of it" is what hid the six variants somebody was looking for.
    #
    # At printing unit the two collapse back into opposites, because a printing is one object: you
    # either have that exact card or you do not. Both rows carry both flags so this does not have to
    # know which unit it is reading.
    # foils is its own axis rather than a third state of the first two: a printing can be one you
    # have, one you are short, and one whose foil you still want, and only the last of those is a
    # question about finishes. It never touches owned or incomplete, so turning it on cannot move
    # the completion numbers above it.
    def keep?(row)
      case @filter
      when 'owned' then row[:owned]
      when 'missing' then row[:incomplete]
      when 'foils' then foils?(row)
      else true
      end
    end

    # Three shapes reach this: a card row, which knows how many of its printings still want a foil;
    # a slot, where the question is simply whether this is a foil slot you have not filled; and a
    # bare printing, which is what the table's strip renders.
    def foils?(row)
      return row[:missing_foils].positive? if row.key?(:missing_foils)
      return row[:finish] == :foil && !row[:owned] if row.key?(:finish)

      row[:missing_foil]
    end

    # Counted off every row rather than off the filtered list, so the toggle can label all three of
    # its buttons from the one pass the page already paid for. At card unit these overlap and do not
    # sum to all - see keep? - which is a property of the question, not a bug in the arithmetic.
    def counts(rows)
      { all: rows.size,
        owned: rows.count { |row| row[:owned] },
        missing: rows.count { |row| row[:incomplete] },
        foils: rows.count { |row| foils?(row) } }
    end
  end
end
