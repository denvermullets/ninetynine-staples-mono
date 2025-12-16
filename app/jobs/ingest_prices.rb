require 'open-uri'

class IngestPrices < ApplicationJob
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
    ingest_prices(json_data['data'])
    admin_user.update(prices_last_updated_at: price_date)
  end

  def ingest_prices(all_info)
    all_info.each do |key, value|
      price_info = value.dig('paper', 'tcgplayer', 'retail')
      next unless price_info.present?

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

    new_value = new_price.values.first
    new_value&.zero? || new_value.nil? ? existing_price : new_value
  end

  def update_price_history(price_history, new_daily_price)
    price_history = { normal: [], foil: [] } if price_history.nil?
    normal = check_existing(price_history['normal'], new_daily_price['normal'])
    foil = check_existing(price_history['foil'], new_daily_price['foil'])

    sync_price_dates(normal, foil)
  end

  def sync_price_dates(normal, foil)
    return { normal:, foil: } unless normal.any? && foil.any?

    common_dates = normal.to_set { |entry| entry.keys.first } & foil.to_set { |entry| entry.keys.first }
    {
      normal: normal.select { |entry| common_dates.include?(entry.keys.first) },
      foil: foil.select { |entry| common_dates.include?(entry.keys.first) }
    }
  end

  def check_existing(existing_data, new_info)
    return [] if existing_data.nil?
    return existing_data if new_info.nil?
    return existing_data if existing_data.any? { |hash| hash.keys.first == new_info.keys.first }

    # Keep track for 90 days, remove oldest if full
    data = existing_data.sort_by { |hash| hash.keys.first } << new_info
    existing_data.count < 90 ? data : data.drop(1)
  end

  def calculate_price_change_weekly(price_history, current_normal_price, current_foil_price)
    return nil if price_history.nil? || price_history.empty?

    seven_days_ago = (Date.today - 7).to_s
    normal_old = find_price_on_or_before_date(price_history['normal'] || [], seven_days_ago)
    foil_old = find_price_on_or_before_date(price_history['foil'] || [], seven_days_ago)

    changes = [
      calculate_percentage_change(normal_old, current_normal_price),
      calculate_percentage_change(foil_old, current_foil_price)
    ].compact

    changes.empty? ? nil : changes.max_by(&:abs)
  end

  def find_price_on_or_before_date(price_array, target_date)
    return nil if price_array.nil? || price_array.empty?

    entry = price_array.sort_by { |e| e.keys.first }.reverse.find { |e| e.keys.first <= target_date }
    return nil unless entry

    entry.values.first.to_f
  end

  def calculate_percentage_change(old_price, new_price)
    return nil if old_price.nil? || new_price.nil?
    return nil if old_price.zero?

    ((new_price - old_price) / old_price * 100).round(2)
  end
end
