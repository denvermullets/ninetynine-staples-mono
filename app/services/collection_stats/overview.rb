# Headline numbers for the analytics dashboard.
#
# Every figure here comes from ONE ungrouped aggregate. The KPI grid, the foil/non-foil split and
# the real/proxy split are all sums over the same joined set, so splitting them into three
# services would mean three identical scans of collection_magic_cards for no benefit.
#
# Foil-vs-nonfoil and real-vs-proxy are treated as two independent axes over the same pile of
# cards, not as four mutually exclusive groups - "how much of my collection is foil" is a
# question about proxies too.
module CollectionStats
  class Overview < Base
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
      weekly_delta: "SUM(#{Sql::WEEKLY_DELTA})"
    }.freeze

    EMPTY = COLUMNS.keys.index_with(0).freeze

    def call
      raw = no_collections? ? EMPTY : fetch

      counts(raw).merge(values(raw)).merge(shares(raw))
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
