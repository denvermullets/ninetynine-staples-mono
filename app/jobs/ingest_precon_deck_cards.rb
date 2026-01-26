class IngestPreconDeckCards < ApplicationJob
  queue_as :background

  DECK_URL_BASE = 'https://mtgjson.com/api/v5/decks'.freeze

  def perform(precon_deck_id)
    precon_deck = PreconDeck.find(precon_deck_id)
    return unless precon_deck.needs_card_sync?

    puts "Loading deck cards for: #{precon_deck.name}"
    deck_data = fetch_deck_data(precon_deck.file_name)
    return unless deck_data

    # Clear existing cards and re-ingest to catch any updates
    precon_deck.precon_deck_cards.delete_all

    # Process all board types from MTGJson deck structure
    PreconDeckCard::BOARD_TYPES.each do |board_type|
      process_board(precon_deck, deck_data[board_type], board_type)
    end
  end

  private

  def fetch_deck_data(file_name)
    encoded_name = URI.encode_uri_component(file_name)
    response = HTTParty.get("#{DECK_URL_BASE}/#{encoded_name}.json")
    return nil unless response.success?

    response.parsed_response['data']
  rescue StandardError => e
    puts "Failed to fetch deck #{file_name}: #{e.message}"
    nil
  end

  def process_board(precon_deck, cards, board_type)
    return unless cards.present?

    cards.each do |card|
      magic_card = MagicCard.find_by(card_uuid: card['uuid'])
      next unless magic_card

      PreconDeckCard.find_or_create_by(
        precon_deck: precon_deck,
        magic_card: magic_card,
        board_type: board_type
      ) do |pdc|
        pdc.quantity = card['count'] || 1
        pdc.is_foil = card['isFoil'] || false
      end
    end
  end
end
