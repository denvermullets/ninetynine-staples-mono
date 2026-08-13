# The header numbers for one set, measured against one collection.
#
# The completion panel ranks every set at once and can only afford four counters per row. This is the
# other half: you clicked a row, so now the expensive questions are worth asking - what are the cards
# you hold from this set actually worth, what would the rest of them cost, and is the tail you have
# left cheap commons or four mythics.
#
# The headline pair comes off SetBasis, the same definitions the panel used, so the percentage here
# is the percentage on the row you clicked. Two queries: the counters and the money in one aggregate,
# the missing-by-rarity breakdown in a second because it is the only figure that needs a GROUP BY.
#
# Both money figures and the counters are real copies only - REAL_COPIES rides on the join, so a
# printing you hold only as a proxy reads as one you are missing, and its price lands in the cost to
# finish. That is the point: the cost is what you would still have to spend.
module CollectionStats
  class SetDetail < Base
    include SetBasis

    # The order a collector reads a leftovers list in - the expensive end first, because that is the
    # part that decides whether finishing the set is a weekend or a year.
    RARITY_ORDER = %w[mythic rare uncommon common].freeze

    UNOWNED = 'owned.magic_card_id IS NULL'.freeze

    # Foils are a SEPARATE metric, not a component of the one above. Completion asks whether you
    # have the card; this asks whether you have it in foil, and a collector who wants the set in
    # foil is answering a different question from one who wants the set. Folding the two together
    # would move this page's percentage off the completion panel row it was opened from, and would
    # tell somebody with a complete non-foil run that they are at 40%.
    MISSING_FOIL = "#{FOIL_AVAILABLE} AND NOT (#{FOIL_OWNED})".freeze

    FOIL_PRICE = 'COALESCE(magic_cards.foil_price, 0)'.freeze

    # The basis is not known until the counts come back, so both are measured and the row picks one
    # afterwards. Cheaper than it looks - it is another FILTER over rows already being scanned, and
    # the alternative is a second round trip to ask the same question a different way.
    COLUMNS = [
      'COUNT(*)', "COUNT(*) FILTER (WHERE #{IN_BASE})",
      'COUNT(owned.magic_card_id)', "COUNT(owned.magic_card_id) FILTER (WHERE #{IN_BASE})",
      "COALESCE(SUM(#{REAL_VALUE}), 0)",
      "COALESCE(SUM(#{COPY_PRICE}) FILTER (WHERE #{UNOWNED}), 0)",
      "COALESCE(SUM(#{COPY_PRICE}) FILTER (WHERE #{UNOWNED} AND #{IN_BASE}), 0)"
    ].freeze

    # Measured on the same basis as the headline, so "245 / 281" and "30 / 275" sit next to each
    # other and mean comparable things. The denominator is the printings that HAVE a foil, not every
    # printing - a card never sold in foil is not one you are missing the foil of.
    FOIL_COLUMNS = [
      "COUNT(*) FILTER (WHERE #{FOIL_AVAILABLE})",
      "COUNT(*) FILTER (WHERE #{FOIL_AVAILABLE} AND #{IN_BASE})",
      "COUNT(*) FILTER (WHERE #{FOIL_AVAILABLE} AND #{FOIL_OWNED})",
      "COUNT(*) FILTER (WHERE #{FOIL_AVAILABLE} AND #{FOIL_OWNED} AND #{IN_BASE})",
      "COALESCE(SUM(#{FOIL_PRICE}) FILTER (WHERE #{MISSING_FOIL}), 0)",
      "COALESCE(SUM(#{FOIL_PRICE}) FILTER (WHERE #{MISSING_FOIL} AND #{IN_BASE}), 0)"
    ].freeze

    def initialize(collection_ids:, boxset:)
      super(collection_ids: collection_ids)
      @boxset = boxset
    end

    def call
      total_all, total_base, owned_all, owned_base, value, cost_all, cost_base = counters
      base = base_run?(total_base.to_i, total_all.to_i)

      headline(base ? owned_base.to_i : owned_all.to_i, base ? total_base.to_i : total_all.to_i)
        .merge(set_identity)
        .merge(variants(base, owned_all.to_i, total_all.to_i))
        .merge(value: to_money(value), cost_to_complete: to_money(base ? cost_base : cost_all),
               foils: foils(base), missing_by_rarity: missing_by_rarity(base))
    end

    private

    # The pair the bar is NOT drawn from, kept beside the one it is so a reader who collects the
    # variants can see where they stand without the page having to pick a side
    def variants(base, owned_all, total_all)
      { basis: base ? :base : :all, variant_owned: owned_all, variant_total: total_all,
        variant_share: share(owned_all, total_all) }
    end

    def set_identity
      { label: @boxset.name || 'Unknown set', code: @boxset.code,
        icon: keyrune_icon(@boxset.keyrune_code), year: @boxset.release_date&.year }
    end

    # One row, both groups. The foil counters are more FILTERs over rows this query is already
    # scanning, so asking for them separately would be a second pass for nothing.
    def row
      @row ||= cards.pick(*(COLUMNS + FOIL_COLUMNS).map { |column| Arel.sql(column) })
    end

    def counters
      row.first(COLUMNS.size)
    end

    def foils(base)
      total_all, total_base, owned_all, owned_base, cost_all, cost_base = row.last(FOIL_COLUMNS.size)

      headline(base ? owned_base.to_i : owned_all.to_i, base ? total_base.to_i : total_all.to_i)
        .merge(cost: to_money(base ? cost_base : cost_all))
    end

    # Ordered here rather than in the view, and by rarity rather than by count, so the chips read the
    # same way every time you open a set instead of reshuffling as you buy things.
    def missing_by_rarity(base)
      counts = cards.group('magic_cards.rarity').pluck(
        Arel.sql('magic_cards.rarity'),
        Arel.sql("COUNT(*) FILTER (WHERE #{UNOWNED})"),
        Arel.sql("COUNT(*) FILTER (WHERE #{UNOWNED} AND #{IN_BASE})")
      )

      rows = counts.to_h { |rarity, all, in_base| [rarity.to_s, (base ? in_base : all).to_i] }

      rows.reject { |_, count| count.zero? }
          .sort_by { |rarity, _| RARITY_ORDER.index(rarity) || RARITY_ORDER.size }
          .to_h
    end

    # No owned_sets CTE, unlike the panel: the set is already named, and the LEFT JOIN is bounded by
    # boxset_id rather than by which sets the viewer has touched. A set you own nothing from is a
    # legitimate thing to open this page on - every card is simply missing.
    def cards
      MagicCard
        .with(owned: owned_rows)
        .joins(:boxset)
        .joins("LEFT JOIN owned ON owned.magic_card_id = magic_cards.id AND #{REAL_COPIES}")
        .where(boxset_id: @boxset.id, is_token: false)
        .where(PRINTABLE)
    end
  end
end
