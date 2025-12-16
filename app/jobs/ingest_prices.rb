require 'open-uri'

class IngestPrices < ApplicationJob
  def perform
    puts 'loading AllPricesToday.json from mtgjson.com'
    # /Users/denvermullets/Downloads/000-mtg/AllPricesToday.json
    # source = File.read('/Users/denvermullets/Downloads/000-mtg/AllPricesToday.json')
    source = URI.open('https://mtgjson.com/api/v5/AllPricesToday.json')
    puts 'completed loading AllPricesToday.json from mtgjson.com'
    # all_info = JSON.parse(source)['data']
    json_data = JSON.parse(source.read)
    price_date = json_data['meta']['date']
    # storing the checksum date on parent admin user
    admin_user = User.where(role: 9001).first
    puts "are prices the same since last price check? #{price_date == admin_user.prices_last_updated_at}"
    return if price_date == admin_user.prices_last_updated_at

    puts 'prices out of date, updating prices'
    all_info = json_data['data']
    ingest_prices(all_info)
    admin_user.update(prices_last_updated_at: price_date)
  end

  def ingest_prices(all_info)
    all_info.each do |key, value|
      next unless value['paper'].present?
      next unless value['paper']['tcgplayer'].present?
      next unless value['paper']['tcgplayer']['retail'].present?

      price_info = value['paper']['tcgplayer']['retail']
      puts "#{key}, #{price_info}"
      update_card(key, price_info)
    end
  end

  def update_card(card_uuid, price_info)
    card = MagicCard.find_by(card_uuid:)
    return unless card.present?

    normal_price = find_price(card.normal_price, price_info['normal']) || 0
    foil_price = find_price(card.foil_price, price_info['foil']) || 0
    price_history = update_price_history(card.price_history, price_info)
    price_change_weekly = calculate_price_change_weekly(price_history, normal_price, foil_price)
    card.update(normal_price:, foil_price:, price_history:, price_change_weekly:)
    UpdateCollections.perform_later(card)
  end

  private

  def find_price(existing_price, new_price)
    return nil if new_price.nil?

    # if the price drops to 0 or is nil leave an existing price if possible
    if new_price.values.first.zero? || new_price.values.first.nil?
      existing_price
    else
      # { "2025-01-05" => 0.13 } - return the value only
      new_price&.values&.first
    end
  end

  def update_price_history(price_history, new_daily_price)
    price_history = { normal: [], foil: [] } if price_history.nil?
    normal = check_existing(price_history['normal'], new_daily_price['normal'])
    foil = check_existing(price_history['foil'], new_daily_price['foil'])

    # Sync dates between foil and normal to prevent chart misalignment
    synced_data = sync_price_dates(normal, foil)

    { normal: synced_data[:normal], foil: synced_data[:foil] }
  end

  def sync_price_dates(normal, foil)
    # Get all dates from both arrays
    normal_dates = normal.to_set { |entry| entry.keys.first }
    foil_dates = foil.to_set { |entry| entry.keys.first }

    # Find common dates (dates that exist in both)
    common_dates = normal_dates & foil_dates

    # If both have data, only keep entries with common dates
    # If only one has data, keep all of it
    if normal.any? && foil.any?
      synced_normal = normal.select { |entry| common_dates.include?(entry.keys.first) }
      synced_foil = foil.select { |entry| common_dates.include?(entry.keys.first) }
      { normal: synced_normal, foil: synced_foil }
    else
      { normal:, foil: }
    end
  end

  def check_existing(existing_data, new_info)
    return [] if existing_data.nil?
    return existing_data if new_info.nil?

    # check if date is already in array, if so leave
    date_to_check = new_info.keys.first
    exists = existing_data.any? { |hash| hash.keys.first == date_to_check }
    return existing_data if exists

    # keep track for 90 days
    data = existing_data.sort_by { |hash| hash.keys.first }
    data << new_info
    if existing_data.count < 90
      data
    else
      # remove oldest date
      data.drop(1)
    end
  end

  def calculate_price_change_weekly(price_history, current_normal_price, current_foil_price)
    return nil if price_history.nil? || price_history.empty?

    seven_days_ago = (Date.today - 7).to_s

    # Get prices from 7 days ago
    normal_history = price_history['normal'] || []
    foil_history = price_history['foil'] || []

    normal_old_price = find_price_on_or_before_date(normal_history, seven_days_ago)
    foil_old_price = find_price_on_or_before_date(foil_history, seven_days_ago)

    # Calculate percentage changes
    normal_pct = calculate_percentage_change(normal_old_price, current_normal_price)
    foil_pct = calculate_percentage_change(foil_old_price, current_foil_price)

    # Use the higher absolute value percentage (could be positive or negative)
    changes = [normal_pct, foil_pct].compact
    return nil if changes.empty?

    changes.max_by(&:abs)
  end

  def find_price_on_or_before_date(price_array, target_date)
    return nil if price_array.nil? || price_array.empty?

    # Sort entries by date and find the most recent one on or before target_date
    sorted_entries = price_array.sort_by { |entry| entry.keys.first }

    sorted_entries.reverse_each do |entry|
      date = entry.keys.first
      return entry[date].to_f if date <= target_date
    end

    nil
  end

  def calculate_percentage_change(old_price, new_price)
    return nil if old_price.nil? || new_price.nil?
    return nil if old_price.zero?

    ((new_price - old_price) / old_price * 100).round(2)
  end
end
