# frozen_string_literal: true

module MagicCards
  class PriceExtremes < Service
    DAYS = 90

    def initialize(price_history)
      @price_history = price_history
    end

    def call
      return {} unless @price_history.present?

      cutoff = DAYS.days.ago.to_date

      %w[normal foil].each_with_object({}) do |type, result|
        entries = recent_entries(@price_history[type], cutoff)
        next if entries.empty?

        prices = entries.map { |e| e.values.first }
        result[type.to_sym] = { high: prices.max, low: prices.min }
      end
    end

    private

    def recent_entries(entries, cutoff)
      return [] unless entries.present?

      entries.select { |e| Date.parse(e.keys.first) >= cutoff }
    end
  end
end
