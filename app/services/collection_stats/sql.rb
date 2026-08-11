# The one place the four quantity buckets get priced.
#
# collection_magic_cards splits ownership across four counters (real/foil/proxy/proxy-foil) and
# each one is worth a different number, so every panel on the analytics dashboard would otherwise
# re-derive the same CASE expressions and drift apart. These constants are the single definition,
# and they are written against the `owned` CTE that CollectionStats::Base builds.
#
# The proxy expressions mirror MagicCard#proxy_normal_price / #proxy_foil_price - a proxy of a
# foil-only printing still has to be worth something, so each finish falls back to the other.
# Prices are nullable despite the 0.0 default, hence COALESCE on every reference.
module CollectionStats
  module Sql
    PROXY_NORMAL = <<~SQL.squish.freeze
      CASE WHEN COALESCE(magic_cards.normal_price, 0) > 0
           THEN magic_cards.normal_price
           ELSE COALESCE(magic_cards.foil_price, 0) END
    SQL

    PROXY_FOIL = <<~SQL.squish.freeze
      CASE WHEN COALESCE(magic_cards.foil_price, 0) > 0
           THEN magic_cards.foil_price
           ELSE COALESCE(magic_cards.normal_price, 0) END
    SQL

    REAL_VALUE = <<~SQL.squish.freeze
      ((owned.qty * COALESCE(magic_cards.normal_price, 0))
       + (owned.foil_qty * COALESCE(magic_cards.foil_price, 0)))
    SQL

    PROXY_VALUE = <<~SQL.squish.freeze
      ((owned.proxy_qty * (#{PROXY_NORMAL}))
       + (owned.proxy_foil_qty * (#{PROXY_FOIL})))
    SQL

    TOTAL_VALUE = "(#{REAL_VALUE} + #{PROXY_VALUE})".freeze

    TOTAL_QTY = '(owned.qty + owned.foil_qty + owned.proxy_qty + owned.proxy_foil_qty)'.freeze

    REAL_QTY = '(owned.qty + owned.foil_qty)'.freeze

    # what Card Kingdom would actually hand you for the real copies - proxies have no buylist
    BUYLIST_VALUE = <<~SQL.squish.freeze
      ((owned.qty * COALESCE(magic_cards.ck_buylist_normal_price, 0))
       + (owned.foil_qty * COALESCE(magic_cards.ck_buylist_foil_price, 0)))
    SQL

    # price_change_weekly_* is a PERCENTAGE (IngestPrices#calculate_percentage_change computes
    # ((new - old) / old) * 100), so it cannot be summed as money. Recovering the dollar move
    # from the percentage and the current price: old = new / (1 + pct/100), therefore
    # delta = new - old = new * pct / (100 + pct).
    #
    # NULLIF guards pct = -100 (price fell to zero), where the old price is unrecoverable from
    # the percentage alone - those cards contribute 0 rather than poisoning the sum.
    #
    # Proxies are excluded on purpose: a proxy's price did not move, you did not gain anything.
    def self.weekly_delta(qty_column, price_column, change_column)
      <<~SQL.squish
        (#{qty_column} * COALESCE(
          COALESCE(magic_cards.#{price_column}, 0) * magic_cards.#{change_column}
            / NULLIF(100 + magic_cards.#{change_column}, 0), 0))
      SQL
    end

    WEEKLY_DELTA = <<~SQL.squish.freeze
      (#{weekly_delta('owned.qty', 'normal_price', 'price_change_weekly_normal')}
       + #{weekly_delta('owned.foil_qty', 'foil_price', 'price_change_weekly_foil')})
    SQL
  end
end
