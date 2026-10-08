# Presentation for the sell page. The rows are CollectionStats::SellList hashes and the filters are
# its normalised filters. The amount, set icon and rarity helpers are the movers page's - same
# shapes, so they are reused rather than copied.
module CollectionSellHelper
  SELL_AMOUNT_FILTERS = %i[min_buylist max_buylist].freeze

  SELL_SORT_HEADERS = {
    'name' => 'Name', 'rarity' => 'Rarity', 'copies' => 'Copies', 'price' => 'Unit price',
    'buylist' => 'CK buylist', 'payout' => 'Payout'
  }.freeze

  # the filters as they ride on a link, unset ones dropped and the page left off - see movers_query
  def sell_query(filters, collection_id, **overrides)
    query = filters.merge(overrides).to_h do |key, value|
      [key, SELL_AMOUNT_FILTERS.include?(key.to_sym) ? movers_amount(value) : value]
    end

    query.merge(collection_id: collection_id).compact_blank
  end

  def sell_sort_link(key, filters:, username:, collection_id:)
    active = filters[:sort] == key
    dir = if active
            filters[:dir] == 'asc' ? 'desc' : 'asc'
          else
            CollectionStats::SellList::DEFAULT_DIRS[key]
          end

    link_to collection_sell_path(username, **sell_query(filters, collection_id, sort: key, dir: dir)),
            class: "inline-flex items-center gap-1 hover:text-accent-50 #{'text-accent-50' if active}" do
      safe_join([SELL_SORT_HEADERS.fetch(key), (movers_sort_arrow(filters[:dir]) if active)].compact)
    end
  end

  def sell_payment_text(filters)
    filters[:payment] == 'credit' ? 'in store credit' : 'in cash'
  end

  # "Trade Binder ×2, Bulk ×1" - where to go and pull the copies from
  def sell_places(row)
    row[:places].map { |place| "#{place[:name]} ×#{number_with_delimiter(place[:copies])}" }.join(', ')
  end
end
