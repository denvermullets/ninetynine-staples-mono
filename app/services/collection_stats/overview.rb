# Headline numbers for the analytics dashboard.
#
# Every figure here comes from ONE ungrouped aggregate. The KPI grid, the foil/non-foil split and
# the real/proxy split are all sums over the same joined set, so splitting them into three
# services would mean three identical scans of collection_magic_cards for no benefit.
#
# Foil-vs-nonfoil, real-vs-proxy and bulk-vs-not are treated as three independent axes over the
# same pile of cards, not as mutually exclusive groups - "how much of my collection is foil" is a
# question about proxies too, and both foils and proxies can be bulk.
#
# The bulk axis is the one that has to be priced per COPY rather than per printing: a 40c non-foil
# and its $30 foil are one row here, and calling that row "bulk" or "not" would be wrong either
# way. Sql.copies_where_price splits the row's four quantity buckets on their own prices, and the
# threshold is read off PriceTiers' first tier so this number and the Price Buckets panel cannot
# drift apart.
module CollectionStats
  class Overview < Base
    # whatever PriceTiers calls its bottom tier is what bulk means, here and there
    BULK_TIER = PriceTiers::TIERS.first
    BULK_CEILING = BULK_TIER[:ceiling]

    COLUMNS = {
      unique_printings: 'COUNT(*)',
      unique_sets: 'COUNT(DISTINCT magic_cards.boxset_id)',
      qty: 'SUM(owned.qty)',
      foil_qty: 'SUM(owned.foil_qty)',
      proxy_qty: 'SUM(owned.proxy_qty)',
      proxy_foil_qty: 'SUM(owned.proxy_foil_qty)',
      normal_value: 'SUM(owned.qty * COALESCE(magic_cards.normal_price, 0))',
      foil_value: 'SUM(owned.foil_qty * COALESCE(magic_cards.foil_price, 0))',
      proxy_value: "SUM(owned.proxy_qty * (#{Sql::PROXY_NORMAL}))",
      proxy_foil_value: "SUM(owned.proxy_foil_qty * (#{Sql::PROXY_FOIL}))",
      buylist_value: "SUM(#{Sql::BUYLIST_VALUE})",
      weekly_delta: "SUM(#{Sql::WEEKLY_DELTA})",
      bulk_qty: Sql.copies_where_price("< #{BULK_CEILING}"),
      bulk_value: Sql.value_where_price("< #{BULK_CEILING}")
    }.freeze

    EMPTY = COLUMNS.keys.index_with(0).freeze

    def call
      raw = no_collections? ? EMPTY : fetch

      counts(raw).merge(values(raw)).merge(shares(raw)).merge(bulk(raw))
    end

    private

    def fetch
      values = owned_cards.pick(*COLUMNS.values.map { |sql| Arel.sql(sql) })
      COLUMNS.keys.zip(Array(values)).to_h { |key, value| [key, value || 0] }
    end

    # SUM() through a raw pick has no column type to key off, so integer quantities come back
    # as BigDecimal. Cast them or the views render "0.318e3" instead of "318".
    def counts(raw)
      {
        unique_printings: raw[:unique_printings].to_i,
        unique_sets: raw[:unique_sets].to_i,
        total_cards: (real_cards(raw) + proxy_cards(raw)).to_i,
        real_cards: real_cards(raw).to_i,
        proxy_cards: proxy_cards(raw).to_i,
        nonfoil_cards: (raw[:qty] + raw[:proxy_qty]).to_i,
        foil_cards: (raw[:foil_qty] + raw[:proxy_foil_qty]).to_i
      }
    end

    def values(raw)
      {
        total_value: to_money(real_value(raw) + proxy_value(raw)),
        real_value: to_money(real_value(raw)),
        proxy_value: to_money(proxy_value(raw)),
        nonfoil_value: to_money(raw[:normal_value] + raw[:proxy_value]),
        foil_value: to_money(raw[:foil_value] + raw[:proxy_foil_value]),
        buylist_value: to_money(raw[:buylist_value]),
        weekly_delta: to_money(raw[:weekly_delta]),
        # divides by real copies only - proxies carry notional value and would drag down an
        # average that is meant to answer "what is a card in here typically worth"
        avg_card_value: to_money(average_card_value(raw))
      }
    end

    def shares(raw)
      total = real_cards(raw) + proxy_cards(raw)

      {
        foil_share: share(raw[:foil_qty] + raw[:proxy_foil_qty], total),
        proxy_share: share(proxy_cards(raw), total),
        # what you would actually get back selling the real copies to Card Kingdom
        buylist_ratio: share(raw[:buylist_value], real_value(raw))
      }
    end

    # Kept apart from counts and values because it is the one split priced per copy rather than per
    # printing, and because both of its sides are derived from one aggregate instead of two.
    def bulk(raw)
      cards = real_cards(raw) + proxy_cards(raw)
      value = real_value(raw) + proxy_value(raw)

      {
        bulk_cards: raw[:bulk_qty].to_i,
        bulk_value: to_money(raw[:bulk_value]),
        # subtracted rather than summed a second time, so the two sides always add up to the totals
        # sitting beside them however the price expressions change
        priced_cards: (cards - raw[:bulk_qty]).to_i,
        priced_value: to_money(value - raw[:bulk_value]),
        priced_share: share(cards - raw[:bulk_qty], cards)
      }
    end

    def average_card_value(raw)
      return 0 if real_cards(raw).zero?

      real_value(raw) / real_cards(raw)
    end

    def real_cards(raw)
      raw[:qty] + raw[:foil_qty]
    end

    def proxy_cards(raw)
      raw[:proxy_qty] + raw[:proxy_foil_qty]
    end

    def real_value(raw)
      raw[:normal_value] + raw[:foil_value]
    end

    def proxy_value(raw)
      raw[:proxy_value] + raw[:proxy_foil_value]
    end
  end
end
