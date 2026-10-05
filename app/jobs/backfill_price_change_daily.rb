class BackfillPriceChangeDaily < ApplicationJob
  queue_as :background

  def perform
    puts 'Starting backfill of price_change_daily for all magic cards'

    total_cards = MagicCard.count
    updated_count = 0
    skipped_count = 0

    MagicCard.find_each.with_index do |card, index|
      result = process_card(card)
      updated_count += 1 if result == :updated
      skipped_count += 1 if result == :skipped

      puts "Processed #{index + 1}/#{total_cards} cards" if ((index + 1) % 1000).zero?
    end

    puts "Backfill complete: #{updated_count} cards updated, #{skipped_count} cards skipped (no price history)"
  end

  private

  def process_card(card)
    return :skipped unless card.price_history.present?

    price_change_daily_normal, price_change_daily_foil = MagicCards::PriceChange.call(
      card.price_history,
      card.normal_price || 0,
      card.foil_price || 0,
      days: 1
    )

    card.update_columns(
      price_change_daily_normal: price_change_daily_normal,
      price_change_daily_foil: price_change_daily_foil
    )

    :updated
  end
end
