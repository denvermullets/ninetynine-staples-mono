# Presentation for the movers page. The rows are CollectionStats::MoversTable hashes and the filters
# are its normalised filters, so the amounts arrive as BigDecimal.
module CollectionMoversHelper
  AMOUNT_FILTERS = %i[min_delta min_percent min_price min_buylist max_buylist].freeze

  SORT_HEADERS = {
    'name' => 'Name', 'rarity' => 'Rarity', 'price' => 'Unit price', 'buylist' => 'CK buylist',
    'delta' => '$ move', 'percent' => '% move'
  }.freeze

  # BigDecimal#to_s is "0.5e1", which reads badly in a field and worse in a URL
  def movers_amount(value)
    return if value.nil?

    value.to_s('F').delete_suffix('.0')
  end

  # The filters as they ride on a link: amounts as plain numbers, unset ones and an empty rarity pick
  # dropped. The page param
  # is left off on purpose - a new sort is a new list, and page 3 of the old one means nothing.
  def movers_query(filters, collection_id, **overrides)
    query = filters.merge(overrides).to_h do |key, value|
      [key, AMOUNT_FILTERS.include?(key.to_sym) ? movers_amount(value) : value]
    end

    query.merge(collection_id: collection_id).compact_blank
  end

  # Clicking the active column flips it; clicking another one starts it at that key's natural
  # direction - biggest first, or A-Z for name.
  def movers_sort_dir(key, filters)
    return CollectionStats::MoversTable::DEFAULT_DIRS[key] unless filters[:sort] == key

    filters[:dir] == 'asc' ? 'desc' : 'asc'
  end

  def movers_sort_link(key, filters:, username:, collection_id:)
    active = filters[:sort] == key
    query = movers_query(filters, collection_id, sort: key, dir: movers_sort_dir(key, filters))

    link_to collection_movers_path(username, **query),
            class: "inline-flex items-center gap-1 hover:text-accent-50 #{'text-accent-50' if active}" do
      safe_join([SORT_HEADERS.fetch(key), (movers_sort_arrow(filters[:dir]) if active)].compact)
    end
  end

  def movers_sort_arrow(dir)
    content_tag(:span, dir == 'asc' ? '▲' : '▼', class: 'text-[10px]', 'aria-hidden': true)
  end

  # the unit prices for the finishes actually held, so a foil-only row never shows a non-foil price
  def movers_unit_price(row)
    parts = []
    parts << number_to_currency(row[:normal_price]) if row[:qty].positive?
    parts << "#{number_to_currency(row[:foil_price])} foil" if row[:foil_qty].positive?
    parts.join(' / ')
  end

  # the same, for what Card Kingdom pays - a finish CK is not buying shows as a dash
  def movers_buylist(row)
    parts = []
    parts << movers_buylist_amount(row[:buylist_normal]) if row[:qty].positive?
    parts << "#{movers_buylist_amount(row[:buylist_foil])} foil" if row[:foil_qty].positive?
    parts.join(' / ')
  end

  # A row is one printing, so unlike the stats panels its set glyph can carry the rarity colour
  def movers_set_icon(row)
    return if row[:icon].blank?

    row[:rarity].present? ? "#{row[:icon]} ss-grad ss-#{row[:rarity].downcase}" : row[:icon]
  end

  def movers_delta(row)
    "#{row[:delta].negative? ? '-' : '+'}#{number_to_currency(row[:delta].abs)}"
  end

  def movers_percent(row)
    "#{'+' unless row[:percent].negative?}#{row[:percent]}%"
  end

  # the finish a row's alert bell starts on: foil when foil is all that is held
  def movers_alert_finish(row)
    row[:qty].zero? && row[:foil_qty].positive? ? 'foil' : 'normal'
  end

  # PriceAlert.movement_rule_attributes as the params the "alert me" button posts to price_alerts#create
  def movers_alert_params(attributes)
    attributes.compact_blank.transform_values { |value| value.is_a?(BigDecimal) ? movers_amount(value) : value }
              .merge(kind: 'movement')
  end

  # a rule with no minimum move would fire on every card that moved at all, every day
  def movers_alert_ready?(attributes)
    attributes[:min_delta_amount].present? || attributes[:min_delta_percent].present?
  end

  # keyrune's rarity colours; it has no special, so special borrows timeshifted's purple
  RARITY_ICONS = { 'mythic' => 'ss-mythic', 'rare' => 'ss-rare', 'uncommon' => 'ss-uncommon',
                   'common' => 'ss-common', 'special' => 'ss-timeshifted' }.freeze

  # the rarity toggles, mythic down to common as the card search draws them: value => icon class
  def movers_rarity_options
    RARITY_ICONS
  end

  def movers_window_text(filters)
    filters[:window] == 'daily' ? 'since yesterday' : 'this week'
  end

  private

  def movers_buylist_amount(amount)
    amount.positive? ? number_to_currency(amount) : '-'
  end
end
