# Value distribution across price bands.
#
# This is the one panel that cannot be a plain grouped aggregate. A single collection_magic_cards
# row can hold copies at two DIFFERENT unit prices - a $0.50 non-foil and a $30 foil of the same
# printing belong in two different bands - so bucketing has to happen per copy, not per row.
#
# CROSS JOIN LATERAL (VALUES ...) unpivots the priced buckets into one row each and bands them in a
# single pass. The alternatives are worse: 6 tiers x N finishes of conditional aggregates, or a
# query per finish stitched together in Ruby.
#
# Proxies are not here at all. Both columns this panel reports are statements about price - which
# band a copy falls in, and how much value sits in that band - and a proxy has no price to answer
# either with. So its copies and its value both foot to the real totals in the KPI grid.
#
# Written as raw SQL rather than through the Base CTE helpers because the LATERAL has no
# ActiveRecord expression, and half-building it would be more confusing than writing it out.
module CollectionStats
  class PriceTiers < Base
    TIERS = [
      { label: '<$1', ceiling: 1 },
      { label: '$1-5', ceiling: 5 },
      { label: '$5-20', ceiling: 20 },
      { label: '$20-50', ceiling: 50 },
      { label: '$50-100', ceiling: 100 },
      { label: '$100+', ceiling: nil }
    ].freeze

    def call
      return empty_result if no_collections?

      rows = fetch.index_by { |row| row['tier'] }
      build(rows)
    end

    private

    def empty_result
      { tiers: TIERS.map { |tier| blank_tier(tier[:label]) }, top_tier_share: 0.0 }
    end

    def blank_tier(label)
      { label: label, copies: 0, value: 0, share: 0.0, bar_class: 'bg-accent-50' }
    end

    def build(rows)
      total = rows.values.sum { |row| row['value'].to_d }
      tiers = TIERS.map { |tier| tier_row(tier[:label], rows[tier[:label]], total) }

      { tiers: tiers, top_tier_share: tiers.last[:share] }
    end

    def tier_row(label, row, total)
      return blank_tier(label) if row.nil?

      {
        label: label,
        copies: row['copies'].to_i,
        value: to_money(row['value']),
        share: share(row['value'].to_d, total),
        bar_class: 'bg-accent-50'
      }
    end

    def fetch
      ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array([sql, { collection_ids: @collection_ids }])
      ).to_a
    end

    # tier ordering comes from the TIERS constant, never from an ORDER BY on the CASE alias
    def case_expression
      whens = TIERS.filter_map do |tier|
        "WHEN priced.unit_price < #{tier[:ceiling]} THEN '#{tier[:label]}'" if tier[:ceiling]
      end

      "CASE #{whens.join(' ')} ELSE '#{TIERS.last[:label]}' END"
    end

    # hand-rolled rather than reusing Base#owned_rows: the LATERAL below has no ActiveRecord
    # expression, so the whole statement has to be a string anyway
    def owned_cte
      <<~SQL.squish
        WITH owned AS (
          SELECT magic_card_id,
                 SUM(quantity) AS qty,
                 SUM(foil_quantity) AS foil_qty,
                 SUM(proxy_quantity) AS proxy_qty,
                 SUM(proxy_foil_quantity) AS proxy_foil_qty
          FROM collection_magic_cards
          WHERE collection_id IN (:collection_ids)
            AND staged = FALSE
            AND needed = FALSE
          GROUP BY magic_card_id
        )
      SQL
    end

    # Built from Sql::PRICED_BUCKETS rather than spelled out, so the bands and the bulk split on the
    # KPI row can only ever be reading the same buckets at the same prices. That list is real copies
    # only - a proxy has no price and so has no band to sit in.
    def bucket_values
      Sql::PRICED_BUCKETS.map { |qty, price| "(#{qty}, #{price})" }.join(",\n")
    end

    def sql
      <<~SQL.squish
        #{owned_cte}
        SELECT tier, SUM(copies) AS copies, SUM(copies * unit_price) AS value
        FROM (
          SELECT priced.copies, priced.unit_price, #{case_expression} AS tier
          FROM owned
          JOIN magic_cards ON magic_cards.id = owned.magic_card_id
          CROSS JOIN LATERAL (VALUES
            #{bucket_values}
          ) AS priced(copies, unit_price)
          WHERE priced.copies > 0
        ) banded
        GROUP BY tier
      SQL
    end
  end
end
