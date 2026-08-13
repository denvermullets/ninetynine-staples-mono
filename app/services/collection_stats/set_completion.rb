# How close the collection is to finishing each set it touches.
#
# Every other panel asks what is in the binder. This one asks what is missing from it, which means
# the denominator comes from the card table rather than from anything the viewer owns: for each set,
# how many cards does it contain, and how many of those has this collection got.
#
# ONE query does both sides. `owned` is one row per printing the viewer holds, so LEFT JOINing it
# onto magic_cards gives a row per card in the set with a null on the ones nobody owns - COUNT(*) is
# then the set and COUNT(owned.magic_card_id) is the part of it collected. Copies never enter into
# it: four copies of one printing is one card collected, which is why nothing here touches quantity.
#
# `owned_sets` is not a micro-optimisation. Without it the LEFT JOIN groups the entire card table -
# every set that has ever been printed, most of which the viewer owns nothing from - and the panel
# would both cost more and have to throw the empty rows away afterwards.
#
# What counts as a card, what counts as the run, and why proxies do not count as collected all live
# in SetBasis, shared with the set detail page this panel links into.
module CollectionStats
  class SetCompletion < Base
    include SetBasis

    HALF = 50

    COLUMNS = [
      'boxsets.name', 'boxsets.code', 'boxsets.keyrune_code',
      'EXTRACT(YEAR FROM boxsets.release_date)::int',
      'COUNT(*)', "COUNT(*) FILTER (WHERE #{IN_BASE})",
      'COUNT(owned.magic_card_id)', "COUNT(owned.magic_card_id) FILTER (WHERE #{IN_BASE})"
    ].freeze

    EMPTY = { sets: [], complete: 0, half: 0, touched: 0 }.freeze

    def call
      return EMPTY if no_collections?

      rows = fetch.map { |row| completion_row(row) }.sort_by { |row| [-row[:share], -row[:total], row[:label]] }

      { sets: rows }.merge(summary(rows))
    end

    private

    def fetch
      MagicCard
        .with(owned: owned_rows, owned_sets: owned_set_ids)
        .joins(:boxset)
        .joins('JOIN owned_sets ON owned_sets.boxset_id = magic_cards.boxset_id')
        .joins("LEFT JOIN owned ON owned.magic_card_id = magic_cards.id AND #{REAL_COPIES}")
        .where(is_token: false)
        .where(PRINTABLE)
        .group('boxsets.id')
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
    end

    # DISTINCT rather than a GROUP BY: this only exists to name the sets worth scanning, and a
    # boxset_id of NULL simply never matches the join below. REAL_COPIES rides on this join too, so
    # a set held entirely in proxies drops out here instead of showing up at 0%.
    def owned_set_ids
      MagicCard
        .joins("JOIN owned ON owned.magic_card_id = magic_cards.id AND #{REAL_COPIES}")
        .select('DISTINCT magic_cards.boxset_id AS boxset_id')
    end

    # Both pairs ride on every row. The headline is the one the bar and the percentage are drawn
    # from; the other is the sentence underneath it, so a reader who does collect the variants can
    # see where they stand without the panel having to pick a side.
    def completion_row(row)
      name, code, keyrune, year, total_all, total_base, owned_all, owned_base = row
      base = base_run?(total_base.to_i, total_all.to_i)

      headline(base ? owned_base.to_i : owned_all.to_i, base ? total_base.to_i : total_all.to_i)
        .merge(label: name || 'Unknown set', code: code, icon: keyrune_icon(keyrune), year: year,
               basis: base ? :base : :all,
               variant_owned: owned_all.to_i, variant_total: total_all.to_i)
    end

    # complete is counted off the raw pair rather than off share, which rounds - 280 of 281 is 99.6%
    # and would survive a >= 100 test the moment the rounding went the other way
    def summary(rows)
      { complete: rows.count { |row| row[:total].positive? && row[:owned] >= row[:total] },
        half: rows.count { |row| row[:share] >= HALF },
        touched: rows.size }
    end
  end
end
