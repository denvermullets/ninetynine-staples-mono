class BackfillPriceChangeWeekly < ApplicationJob
  def perform
    puts 'Starting backfill of price_change_weekly for all magic cards'

    total_cards = MagicCard.count
    updated_count = 0
    skipped_count = 0

    MagicCard.find_each.with_index do |card, index|
      if card.price_history.present?
        price_change_weekly_normal, price_change_weekly_foil = calculate_price_changes_weekly(
          card.price_history,
          card.normal_price || 0,
          card.foil_price || 0
        )

        card.update_columns(
          price_change_weekly_normal: price_change_weekly_normal,
          price_change_weekly_foil: price_change_weekly_foil
        )
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

  def calculate_price_changes_weekly(price_history, current_normal_price, current_foil_price)
    return [nil, nil] if price_history.nil? || price_history.empty?

    seven_days_ago = (Date.today - 7).to_s
    normal_old_price = find_price_on_or_before_date(price_history['normal'] || [], seven_days_ago)
    foil_old_price = find_price_on_or_before_date(price_history['foil'] || [], seven_days_ago)

    [
      calculate_percentage_change(normal_old_price, current_normal_price),
      calculate_percentage_change(foil_old_price, current_foil_price)
    ]
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
