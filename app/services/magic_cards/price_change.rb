# frozen_string_literal: true

module MagicCards
  # percentage move of each finish against the price_history entry on or before
  # `days` ago. ingest and the backfills share this so the two can't drift.
  # returns [normal, foil], either of which is nil when there's nothing to compare
  class PriceChange < Service
    def initialize(price_history, current_normal_price, current_foil_price, days:)
      @price_history = price_history
      @current_normal_price = current_normal_price
      @current_foil_price = current_foil_price
      @days = days
    end

    def call
      return [nil, nil] if @price_history.blank?

      # ingest builds history with symbol keys, rows read back from the db have strings
      history = @price_history.with_indifferent_access
      target_date = (Date.today - @days).to_s

      [
        percentage_change(price_on_or_before(history[:normal], target_date), @current_normal_price),
        percentage_change(price_on_or_before(history[:foil], target_date), @current_foil_price)
      ]
    end

    private

    def price_on_or_before(price_array, target_date)
      return nil if price_array.blank?

      entry = price_array.sort_by { |e| e.keys.first }.rfind { |e| e.keys.first <= target_date }
      return nil unless entry

      entry.values.first.to_f
    end

    def percentage_change(old_price, new_price)
      return nil if old_price.nil? || new_price.nil?
      return nil if old_price.zero?

      ((new_price - old_price) / old_price * 100).round(2)
    end
  end
end
