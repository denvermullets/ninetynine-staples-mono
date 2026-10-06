# Wording for price bands and their worklists, and the buylist range that bands share with movement
# rules. See PriceAlert and PriceAlerts::SyncBand.
module PriceBandsHelper
  # "CK buylist $0.25-$2.00", "CK buylist $0.25+", "CK buylist up to $2.00", or nil with no range
  def price_alert_buylist_range(alert)
    low, high = [alert.min_buylist_price, alert.max_buylist_price].map { |price| price && number_to_currency(price) }
    range = case [low.present?, high.present?]
            when [true, true] then "#{low}-#{high}"
            when [true, false] then "#{low}+"
            when [false, true] then "up to #{high}"
            end

    "CK buylist #{range}" if range
  end

  # Which moves a band lists, in its own lines: "Up to $1.00 or more, or back to $0.90 or less" for a
  # two-way band, "$0.90 or less to $1.00 or more" going up only, "$1.10 or more to under $1.00"
  # going down only.
  def price_band_condition(alert)
    [price_band_lines(alert), PriceAlertsHelper::FINISH_LABELS.fetch(alert.finish),
     price_alert_buylist_range(alert)].compact.join(', ')
  end

  def price_band_lines(alert)
    from = number_to_currency(alert.from_price)
    to = number_to_currency(alert.threshold_price)

    case alert.direction
    when 'both' then "Up to #{to} or more, or back to #{from} or less"
    when 'above' then "#{from} or less to #{to} or more"
    else "#{from} or more to under #{to}"
    end
  end

  # The heading over one way's moves on the worklist
  def price_band_move_heading(alert, moved)
    if moved == alert.reach_move
      line = number_to_currency(alert.threshold_price)
      moved == 'up' ? "Went up to #{line} or more" : "Dropped under #{line}"
    else
      "Dropped back to #{number_to_currency(alert.from_price)} or less"
    end
  end

  # "Binder A ×2, Trade Box ×1" - where to go and find the card
  def price_band_places(places)
    return 'No longer in this collection' if places.empty?

    places.map { |place| "#{place[:name]} ×#{place[:copies]}" }.join(', ')
  end

  # the set glyph in its rarity colour, as the set tables draw it
  def price_band_set_icon(card)
    keyrune = card.boxset&.keyrune_code
    return if keyrune.blank?

    "no-tailwind ss ss-#{keyrune.downcase} ss-grad ss-#{card.rarity&.downcase || 'common'} ss-fw"
  end

  def price_band_money(amount)
    amount&.positive? ? number_to_currency(amount) : '-'
  end
end
