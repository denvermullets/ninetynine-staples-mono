# Backfills boxset value history using existing card price history data
# This builds a complete historical record by aggregating card prices for each date
class BackfillBoxsetValueHistory < ApplicationJob
  queue_as :background

  def perform
    puts 'Starting boxset value history backfill'

    Boxset.find_each do |boxset|
      backfill_boxset_history(boxset)
    end

    puts 'Completed boxset value history backfill'
  end

  private

  def backfill_boxset_history(boxset)
    puts "Processing boxset: #{boxset.name}"

    # Collect all unique dates from all cards in this boxset
    all_dates = collect_all_dates(boxset)

    return if all_dates.empty?

    # Build value history for each date
    value_history = { 'normal' => [], 'foil' => [] }

    all_dates.sort.each do |date|
      normal_total = calculate_total_for_date(boxset, date, 'normal')
      foil_total = calculate_total_for_date(boxset, date, 'foil')

      value_history['normal'] << { date => normal_total }
      value_history['foil'] << { date => foil_total }
    end

    boxset.update_column(:value_history, value_history)
    puts "  - Recorded #{all_dates.size} dates for #{boxset.name}"
  end

  def collect_all_dates(boxset)
    dates = Set.new

    boxset.magic_cards.find_each do |card|
      next unless card.price_history.present?

      extract_dates_from_price_type(card.price_history['normal'], dates)
      extract_dates_from_price_type(card.price_history['foil'], dates)
    end

    dates
  end

  def extract_dates_from_price_type(price_history, dates)
    return unless price_history.present?

    price_history.each do |entry|
      dates.add(entry.keys.first)
    end
  end

  def calculate_total_for_date(boxset, date, price_type)
    total = 0.0

    boxset.magic_cards.find_each do |card|
      next unless card.price_history.present?
      next unless card.price_history[price_type].present?

      # Find the price for this specific date
      price_entry = card.price_history[price_type].find { |entry| entry.key?(date) }

      if price_entry
        total += price_entry[date].to_f
      else
        # If this card doesn't have a price for this date, use the most recent price before this date
        previous_price = find_previous_price(card.price_history[price_type], date)
        total += previous_price if previous_price
      end
    end

    total
  end

  def find_previous_price(price_array, target_date)
    return nil if price_array.nil? || price_array.empty?

    # Sort entries by date and find the most recent one before target_date
    sorted_entries = price_array.sort_by { |entry| entry.keys.first }

    sorted_entries.reverse_each do |entry|
      date = entry.keys.first
      return entry[date].to_f if date < target_date
    end

    nil
  end
end
