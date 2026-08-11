# Top sets and the release-year timeline, from one scan.
#
# Both questions group the same joined rows by two different keys, so GROUPING SETS answers
# them in a single pass instead of two near-identical queries. GROUPING(boxsets.id) is the
# discriminator - 0 on a set row, 1 on a year row - and Ruby partitions on it.
#
# The year expression sits in BOTH grouping sets. boxsets.id functionally determines the
# release date, so the row count is identical either way, and it means a top-set row can carry
# its year without a second lookup. boxsets.name and keyrune_code are referenced bare: Postgres
# allows any column appearing in at least one grouping set and yields NULL for the others.
#
# Sets are ranked by value rather than copies. The panel beside this one already answers
# "what is in here"; "where is the money" is the question the rest of the dashboard asks.
#
# joins(:boxset) is an inner join. boxset_id is nullable in the schema but belongs_to :boxset
# is required at the model level, so no owned card should be orphaned.
module CollectionStats
  class Sets < Base
    TOP = 10
    OTHER = 'Other sets'.freeze
    UNKNOWN_YEAR = 'Unknown'.freeze

    YEAR = 'EXTRACT(YEAR FROM boxsets.release_date)'.freeze

    GROUPING_SETS = <<~SQL.squish.freeze
      GROUPING SETS (
        (boxsets.id, boxsets.name, boxsets.keyrune_code, #{YEAR}),
        (#{YEAR})
      )
    SQL

    COLUMNS = [
      'GROUPING(boxsets.id)', 'boxsets.name', 'boxsets.keyrune_code', "#{YEAR}::int",
      "SUM(#{TOTAL_QTY})", "SUM(#{TOTAL_VALUE})", 'COUNT(*)'
    ].freeze

    def call
      return { top_sets: [], years: [], set_count: 0 } if no_collections?

      set_rows, year_rows = fetch.partition { |row| row[:set_row] }

      { top_sets: top_sets(set_rows), years: years(year_rows), set_count: set_rows.size }
    end

    private

    def fetch
      owned_cards
        .joins(:boxset)
        .group(Arel.sql(GROUPING_SETS))
        .pluck(*COLUMNS.map { |column| Arel.sql(column) })
        .map { |row| parse(row) }
    end

    def parse(row)
      grouping, name, keyrune, year, copies, value, printings = row

      { set_row: grouping.to_i.zero?, name: name, keyrune: keyrune, year: year,
        copies: copies.to_i, value: to_money(value || 0), printings: printings.to_i }
    end

    def top_sets(rows)
      total = rows.sum { |row| row[:value] }
      ranked = rows.sort_by { |row| [-row[:value], row[:name].to_s] }

      ranked.first(TOP).map { |row| set_row(row, total) } + other_row(ranked.drop(TOP), total)
    end

    def set_row(row, total)
      { label: row[:name] || 'Unknown set', copies: row[:copies], value: row[:value],
        share: share(row[:value], total), icon: keyrune_icon(row[:keyrune]), bar_class: 'bg-accent-50',
        year: row[:year], printings: row[:printings] }
    end

    # the tail is folded into one row rather than dropped, so the shares still sum to 100% and
    # the reader can see how long the tail is
    def other_row(rest, total)
      return [] if rest.empty?

      value = rest.sum { |row| row[:value] }

      [{ label: "#{OTHER} (#{rest.size})", copies: rest.sum { |row| row[:copies] },
         value: value, share: share(value, total), icon: nil, bar_class: 'bg-highlight' }]
    end

    # release_date is nullable, so a year row can come back with no year. It keeps its own
    # label at the end rather than being dropped - those are real cards, and the year totals
    # have to reconcile with the set totals.
    def years(rows)
      known, unknown = rows.partition { |row| row[:year].present? }

      fill(known.index_by { |row| row[:year].to_i }) +
        unknown.map { |row| year_row(UNKNOWN_YEAR, row) }
    end

    # gaps filled with zeroes: a collection with nothing from 2019 or 2020 shows two empty
    # bars rather than butting 2018 against 2021 and implying a continuous run
    def fill(by_year)
      return [] if by_year.empty?

      (by_year.keys.min..by_year.keys.max).map { |year| year_row(year.to_s, by_year[year]) }
    end

    def year_row(label, row)
      { label: label, copies: row ? row[:copies] : 0, value: row ? row[:value] : 0 }
    end
  end
end
