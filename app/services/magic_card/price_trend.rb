# frozen_string_literal: true

module MagicCard
  class PriceTrend < Service
    def initialize(price_history)
      @price_history = price_history
    end

    def call
      return {} unless @price_history.present?

      %w[foil normal].each_with_object({}) do |type, trends|
        trend = calculate_trend_for_type(type)
        trends[type.to_sym] = trend if trend
      end
    end

    def price_change
      price_changes = {}

      %w[foil normal].each do |type|
        prices = @price_history[type]&.last(2) || []
        next unless prices.size == 2

        old_price = prices.first.values.first
        new_price = prices.last.values.first
        price_changes[type] = {
          old_price: old_price, new_price: new_price, change: (new_price - old_price).round(2)
        }
      end

      price_changes
    end

    def trend(days: 7, threshold_percent: 5.0)
      return {} unless @price_history.present?

      %w[foil normal].each_with_object({}) do |type, trends|
        trend = calculate_trend_for_type(type, days, threshold_percent)
        trends[type.to_sym] = trend if trend
      end
    end

    private

    def calculate_trend_for_type(type, days = 7, threshold_percent = 5.0)
      prices = @price_history[type] || []
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
end
