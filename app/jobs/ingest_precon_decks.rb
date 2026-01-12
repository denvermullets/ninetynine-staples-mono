class IngestPreconDecks < ApplicationJob
  DECK_LIST_URL = 'https://mtgjson.com/api/v5/DeckList.json'.freeze

  def perform
    puts 'Loading DeckList.json from mtgjson.com'
    response = HTTParty.get(DECK_LIST_URL)
    all_info = response.parsed_response['data']

    all_info.each do |deck|
      puts "Processing deck: #{deck['name']}"
      precon_deck = find_or_create_deck(deck)

      # Queue card ingestion if not already done
      IngestPreconDeckCards.perform_later(precon_deck.id) unless precon_deck.cards_ingested?
    end
  end

  private

  def find_or_create_deck(deck)
    PreconDeck.find_or_create_by(file_name: deck['fileName']) do |d|
      d.code = deck['code']
      d.name = deck['name']
      d.release_date = deck['releaseDate']
      d.deck_type = deck['type']
    end
  end
end
