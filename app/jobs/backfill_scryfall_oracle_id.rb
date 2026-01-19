class BackfillScryfallOracleId < ApplicationJob
  queue_as :background

  def perform
    puts 'Starting backfill of scryfall_oracle_id for all magic cards'

    total_cards = MagicCard.count
    updated_count = 0
    skipped_count = 0

    MagicCard.find_each.with_index do |card, index|
      result = process_card(card)
      updated_count += 1 if result == :updated
      skipped_count += 1 if result == :skipped

      puts "Processed #{index + 1}/#{total_cards} cards" if ((index + 1) % 1000).zero?
    end

    puts "Backfill complete: #{updated_count} cards updated, #{skipped_count} cards skipped (no scryfallOracleId)"
  end

  private

  def process_card(card)
    scryfall_oracle_id = card.identifiers&.dig('scryfallOracleId')

    return :skipped if scryfall_oracle_id.blank?

    card.update_columns(scryfall_oracle_id: scryfall_oracle_id)

    :updated
  end
end
