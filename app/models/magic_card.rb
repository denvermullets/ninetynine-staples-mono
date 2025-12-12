class MagicCard < ApplicationRecord
  belongs_to :boxset

  has_many :printings

  has_one :card_price

  has_many :magic_card_artists
  has_many :artists, through: :magic_card_artists

  has_many :magic_card_sub_types
  has_many :sub_types, through: :magic_card_sub_types

  has_many :magic_card_super_types
  has_many :super_types, through: :magic_card_super_types

  has_many :magic_card_types
  has_many :card_types, through: :magic_card_types

  has_many :collection_magic_cards, dependent: :destroy
  has_many :collections, through: :collection_magic_cards

  has_many :magic_card_colors
  has_many :colors, through: :magic_card_colors

  has_many :magic_card_color_idents
  has_many :colors, through: :magic_card_color_idents

  has_many :magic_card_rulings
  has_many :rulings, through: :magic_card_rulings

  has_many :magic_card_keywords
  has_many :keywords, through: :magic_card_keywords

  def other_face
    return nil unless other_face_uuid.present?

    MagicCard.find_by(card_uuid: other_face_uuid)
  end

  def double_faced?
    other_face_uuid.present?
  end

  def price_change
    # determine how much value has changed
    price_changes = {}

    %w[foil normal].each do |type|
      prices = price_history[type]&.last(2) || []
      next unless prices.size == 2

      old_price = prices.first.values.first
      new_price = prices.last.values.first
      price_changes[type] = {
        old_price: old_price,
        new_price: new_price,
        change: (new_price - old_price).round(2)
      }
    end

    price_changes
  end

  def price_trend(days: 7, threshold_percent: 5.0)
    # Calculate price trend over specified days with percentage threshold
    # Returns hash: { foil: 'up'|'down'|nil, normal: 'up'|'down'|nil }
    return {} unless price_history.present?

    %w[foil normal].each_with_object({}) do |type, trends|
      trend = calculate_price_trend_for_type(type, days, threshold_percent)
      trends[type.to_sym] = trend if trend
    end
  end

  private

  def calculate_price_trend_for_type(type, days, threshold_percent)
    prices = price_history[type] || []
    return nil if prices.size < 2

    current_price = extract_price(prices.last)
    old_price = extract_price(prices[[prices.size - days - 1, 0].max])

    return nil unless valid_prices?(current_price, old_price)

    percent_change = calculate_percent_change(old_price, current_price)
    trend_direction(percent_change, threshold_percent)
  end

  def extract_price(price_entry)
    price_entry&.values&.first
  end

  def valid_prices?(*prices)
    prices.all? { |p| p&.positive? }
  end

  def calculate_percent_change(old_price, new_price)
    ((new_price - old_price) / old_price * 100).round(2)
  end

  def trend_direction(percent_change, threshold)
    return 'up' if percent_change >= threshold
    return 'down' if percent_change <= -threshold

    nil
  end
end
