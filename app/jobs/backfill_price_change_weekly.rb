class BackfillPriceChangeWeekly < ApplicationJob
  def perform
    puts 'Starting backfill of price_change_weekly for all magic cards'

    total_cards = MagicCard.count
    updated_count = 0
    skipped_count = 0

    MagicCard.find_each.with_index do |card, index|
      if card.price_history.present?
        price_change_weekly = calculate_price_change_weekly(
          card.price_history,
          card.normal_price || 0,
          card.foil_price || 0
        )

        card.update_column(:price_change_weekly, price_change_weekly)
        updated_count += 1
      else
        skipped_count += 1
      end

      # Log progress every 1000 cards
      puts "Processed #{index + 1}/#{total_cards} cards" if ((index + 1) % 1000).zero?
    end

    puts "Backfill complete: #{updated_count} cards updated, #{skipped_count} cards skipped (no price history)"
  end

  private

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
