require 'open-uri'

class IngestPrices < ApplicationJob
  MAX_HISTORY_DAYS = 90

  queue_as :ingest

  def perform
    puts 'loading AllPricesToday.json from mtgjson.com'
    # /Users/denvermullets/Downloads/000-mtg/AllPricesToday.json
    # source = File.read('/Users/denvermullets/Downloads/000-mtg/AllPricesToday.json')
    source = URI.open('https://mtgjson.com/api/v5/AllPricesToday.json')
    puts 'completed loading AllPricesToday.json from mtgjson.com'
    json_data = JSON.parse(source.read)
    price_date = json_data['meta']['date']
    admin_user = User.find_by(role: 9001)

    puts "are prices the same since last price check? #{price_date == admin_user.prices_last_updated_at}"
    return if price_date == admin_user.prices_last_updated_at

    puts 'prices out of date, updating prices'
    ingest_prices(json_data['data'], price_date)
    admin_user.update(prices_last_updated_at: price_date)
  end

  def ingest_prices(all_info, price_date = nil)
    all_info.each do |key, value|
      price_info = value.dig('paper', 'tcgplayer', 'retail')
      ck_buylist_info = value.dig('paper', 'cardkingdom', 'buylist')
      next unless price_info.present? || ck_buylist_info.present?

      puts "#{key}, #{price_info}"
      update_card(key, price_info, ck_buylist_info, price_date)
    end
  end

  def update_card(card_uuid, price_info, ck_buylist_info, price_date = nil)
    card = MagicCard.find_by(card_uuid:)
    return unless card.present?

    tcg_attrs = tcgplayer_attributes(card, price_info, price_date)
    ck_attrs = ck_buylist_attributes(card, ck_buylist_info)

    card.update(**tcg_attrs, **ck_attrs)
    return unless CollectionMagicCard.exists?(magic_card_id: card.id)

    UpdateCollections.perform_later(card, price_date)
  end

  private

  def tcgplayer_attributes(card, price_info, price_date = nil)
    unless price_info
      return { normal_price: card.normal_price, foil_price: card.foil_price,
               price_history: card.price_history, price_change_weekly_normal: card.price_change_weekly_normal,
               price_change_weekly_foil: card.price_change_weekly_foil }
    end

    normal_price = find_price(card.normal_price, price_info['normal']) || 0
    foil_price = find_price(card.foil_price, price_info['foil']) || 0
    price_history = update_price_history(card.price_history, price_info, price_date)
    price_change_weekly_normal, price_change_weekly_foil = calculate_price_changes_weekly(
      price_history, normal_price, foil_price
    )

    { normal_price:, foil_price:, price_history:, price_change_weekly_normal:, price_change_weekly_foil: }
  end

  def ck_buylist_attributes(card, ck_buylist_info)
    unless ck_buylist_info
      return { ck_buylist_normal_price: card.ck_buylist_normal_price,
               ck_buylist_foil_price: card.ck_buylist_foil_price }
    end

    {
      ck_buylist_normal_price: find_price(card.ck_buylist_normal_price, ck_buylist_info['normal']) || 0,
      ck_buylist_foil_price: find_price(card.ck_buylist_foil_price, ck_buylist_info['foil']) || 0
    }
  end

  # missing pricing data doesn't mean the card is worthless - hang onto the last
  # known price instead of cratering it to 0
  def find_price(existing_price, new_price)
    return existing_price if new_price.nil?

    new_value = new_price.values.first
    new_value&.zero? || new_value.nil? ? existing_price : new_value
  end

  # normal and foil are tracked independently. intersecting their dates used to
  # drop the day's entry whenever the other finish had no data, which froze the
  # history for good and left price_change replaying the same stale delta
  def update_price_history(price_history, new_daily_price, price_date = nil)
    price_history ||= {}
    entry_date = price_date || feed_date(new_daily_price)

    {
      normal: check_existing(price_history['normal'] || [], new_daily_price['normal'], entry_date),
      foil: check_existing(price_history['foil'] || [], new_daily_price['foil'], entry_date)
    }
  end

  # the feed keys each price by the day it was pulled, so a run with no explicit
  # date can still recover it from whichever finish reported
  def feed_date(new_daily_price)
    (new_daily_price['normal'] || new_daily_price['foil'])&.keys&.first
  end

  def check_existing(existing_data, new_info, entry_date = nil)
    return [] if existing_data.nil?

    sorted = existing_data.sort_by { |hash| hash.keys.first }
    new_entry = new_info || carry_forward(sorted, entry_date)
    return existing_data if new_entry.nil?
    return existing_data if sorted.any? { |hash| hash.keys.first == new_entry.keys.first }

    trim(sorted + fill_gap(sorted, new_entry.keys.first) + [new_entry])
  end

  # an unreported finish isn't a worthless one. repeat the last known price so
  # both finishes stay on the same daily grid - a hole in one of them shifts
  # every later point on the chart, which plots the two series side by side
  def carry_forward(sorted_data, entry_date)
    return nil if entry_date.nil? || sorted_data.empty?

    { entry_date => sorted_data.last.values.first }
  end

  # a day the ingest never ran leaves the same kind of hole, just in both
  # finishes at once. bridge every missing day with the last known price, however
  # long the stretch - trim drops whatever falls out the back of the window
  def fill_gap(sorted_data, new_date)
    return [] if sorted_data.empty?

    last_date = Date.parse(sorted_data.last.keys.first)
    last_price = sorted_data.last.values.first

    ((last_date + 1)...Date.parse(new_date)).map { |date| { date.to_s => last_price } }
  end

  def trim(data)
    data.last(MAX_HISTORY_DAYS)
  end

  def calculate_price_changes_weekly(price_history, current_normal_price, current_foil_price)
    return [nil, nil] if price_history.nil? || price_history.empty?

    seven_days_ago = (Date.today - 7).to_s
    normal_old = find_price_on_or_before_date(price_history[:normal] || [], seven_days_ago)
    foil_old = find_price_on_or_before_date(price_history[:foil] || [], seven_days_ago)

    [
      calculate_percentage_change(normal_old, current_normal_price),
      calculate_percentage_change(foil_old, current_foil_price)
    ]
  end

  def find_price_on_or_before_date(price_array, target_date)
    return nil if price_array.nil? || price_array.empty?

    entry = price_array.sort_by { |e| e.keys.first }.rfind { |e| e.keys.first <= target_date }
    return nil unless entry

    entry.values.first.to_f
  end

  def calculate_percentage_change(old_price, new_price)
    return nil if old_price.nil? || new_price.nil?
    return nil if old_price.zero?

    ((new_price - old_price) / old_price * 100).round(2)
  end
end
