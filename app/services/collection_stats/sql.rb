# The one place the four quantity buckets get priced.
#
# collection_magic_cards splits ownership across four counters (real/foil/proxy/proxy-foil) and
# each one is worth a different number, so every panel on the analytics dashboard would otherwise
# re-derive the same CASE expressions and drift apart. These constants are the single definition,
# and they are written against the `owned` CTE that CollectionStats::Base builds.
#
# PROXIES CARRY NO VALUE. A proxy is a piece of cardstock you printed; pricing it at what the real
# card sells for inflates every money figure on the dashboard by whatever your proxy pile would
# cost to buy for real, which for a proxied duals/fetches pile is most of the number. So value is
# summed off REAL_VALUE everywhere, and the only proxy money on the page is the notional figure on
# the Real vs Proxy panel, which Overview builds out of PROXY_NORMAL/PROXY_FOIL on its own.
#
# Counts are the other axis and they DO include proxies - "how many cards do I have" has an answer
# that a proxy belongs in, which is why TOTAL_QTY survives next to a value expression that is real
# copies only.
#
# The proxy expressions mirror MagicCard#proxy_normal_price / #proxy_foil_price - a proxy of a
# foil-only printing still has to price off something, so each finish falls back to the other.
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

    # What one more copy of a printing costs to buy, which is a different question from what a copy
    # you already own is worth: the set detail page prices the cards you are MISSING, and a
    # foil-only printing still has a price to pay even though its normal_price is 0.
    #
    # The expression is the same shape as PROXY_NORMAL and deliberately not the same constant -
    # that one prices a proxy of a card you hold, this one prices a card you do not. Merging them
    # would tie the cost-to-finish figure to whatever the proxy panel decides to do next.
    COPY_PRICE = <<~SQL.squish.freeze
      CASE WHEN COALESCE(magic_cards.normal_price, 0) > 0
           THEN magic_cards.normal_price
           ELSE COALESCE(magic_cards.foil_price, 0) END
    SQL

    TOTAL_QTY = '(owned.qty + owned.foil_qty + owned.proxy_qty + owned.proxy_foil_qty)'.freeze

    REAL_QTY = '(owned.qty + owned.foil_qty)'.freeze

    # The same two rules against a bare collection_magic_cards row rather than the summed `owned`
    # CTE, for the queries that have to KEEP collection_id instead of rolling it up - which binder a
    # copy sits in is not a question the CTE can answer, because summing is what it does.
    #
    # Same answer as their CTE counterparts wherever both apply, and they live here next to them so
    # the two forms cannot drift into disagreeing about what a real copy is.
    REAL_ROW = 'collection_magic_cards.quantity + collection_magic_cards.foil_quantity > 0'.freeze

    PROXY_ROW = <<~SQL.squish.freeze
      collection_magic_cards.proxy_quantity + collection_magic_cards.proxy_foil_quantity > 0
    SQL

    # The real quantity buckets paired with the unit price each bucket's copies are actually worth.
    #
    # This is the same pairing PriceTiers unpivots through its LATERAL, and it lives here so it is the
    # same pairing. Anything that asks a question about individual copies has to price them off this
    # list, or two panels end up disagreeing about what a card is worth - a $0.40 non-foil sitting
    # next to its $30 foil is one printing at two prices, and a per-printing average answers neither.
    #
    # The two proxy buckets are absent on purpose. These drive the price-band panels, and putting a
    # proxy in a band asserts it is worth that band - a proxied Underground Sea is not $400 of
    # "$100+", it is a card you cannot sell. Panels built on this list therefore count real copies
    # only, so their copies AND their value both foot to the real totals in the KPI grid.
    PRICED_BUCKETS = [
      ['owned.qty', 'COALESCE(magic_cards.normal_price, 0)'],
      ['owned.foil_qty', 'COALESCE(magic_cards.foil_price, 0)']
    ].freeze

    # ELSE 0 rather than a WHERE: PriceTiers can filter copies > 0 because it made a row per bucket,
    # but these are conditional sums over one row per printing, so an empty bucket has to contribute
    # nothing instead of dropping the printing's other three buckets with it.
    def self.copies_where_price(comparison)
      terms = PRICED_BUCKETS.map do |qty, price|
        "CASE WHEN #{price} #{comparison} THEN #{qty} ELSE 0 END"
      end

      "SUM(#{terms.join(' + ')})"
    end

    def self.value_where_price(comparison)
      terms = PRICED_BUCKETS.map do |qty, price|
        "CASE WHEN #{price} #{comparison} THEN #{qty} * #{price} ELSE 0 END"
      end

      "SUM(#{terms.join(' + ')})"
    end

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
