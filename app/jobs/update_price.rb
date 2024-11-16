require 'open-uri'

class UpdatePrice < ApplicationJob
  def perform(card_uuid, price_info)
    card = MagicCard.find_by(card_uuid:)

    return unless card.present?

    normal_price = find_price(card.normal_price, price_info['normal']).values.first
    foil_price = find_price(card.foil_price, price_info['foil']).values.first
    price_history = update_price_history(card.price_history, price_info)

    puts "updating card #{card_uuid}"
    card.update(normal_price:, foil_price:, price_history:)
    puts "updated card #{card_uuid}"
  end

  def find_price(existing_price, new_price)
    # if the price drops to 0 or is nil leave an existing price if possible
    puts "new price: #{new_price.values.first.nil?}"
    if new_price.values.first.zero? || new_price.values.first.nil?
      existing_price
    else
      new_price
    end
  end

  def update_price_history(price_history, new_daily_price)
    price_history = { normal: [], foil: [] } if price_history.nil?
    puts "price_history: #{price_history}"

    normal = check_existing(price_history[:normal], new_daily_price['normal'])
    foil = check_existing(price_history[:normal], new_daily_price['foil'])

    { normal:, foil: }
  end

  def check_existing(existing_data, new_info)
    puts "new info nil: #{new_info.nil?}"
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
end
