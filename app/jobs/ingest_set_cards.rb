require 'open-uri'

class IngestSetCards < ApplicationJob
  queue_as :background

  def perform(set)
    puts "loading #{set['name']} - #{set['code']}.json from mtgjson.com"
    source = URI.open("https://mtgjson.com/api/v5/#{set['code']}.json")
    puts "completed loading #{set['code']}.json from mtgjson.com"
    all_info = JSON.parse(source.read)['data']

    puts "opening up #{set['name']}"
    boxset = Boxset.find_by(code: set['code'])

    update_boxset(boxset, set)
    process_cards(boxset, all_info['cards'])
    process_tokens(boxset, all_info['tokens']) if all_info['tokens'].present?
  end

  private

  def update_boxset(boxset, set)
    boxset.update(
      code: set['code'],
      name: set['name'],
      release_date: set['releaseDate'],
      base_set_size: set['baseSetSize'],
      total_set_size: set['totalSetSize'],
      set_type: set['type']
    )
  end

  def process_cards(boxset, cards)
    cards.each do |card|
      next unless card['availability'].include?('paper')

      puts "working on card #{card['name']}"
      magic_card = CardIngestion::CardCreator.call(boxset: boxset, card_data: card)
      magic_card.boxset.update(valid_cards: true)

      CardIngestion::AttributeCreator.call(magic_card: magic_card, card_data: card)
    end
  end

  def process_tokens(boxset, tokens)
    tokens.each do |token|
      next unless token['availability'].include?('paper')

      puts "working on token #{token['name']}"
      magic_card = CardIngestion::CardCreator.call(boxset: boxset, card_data: token, is_token: true)

      CardIngestion::AttributeCreator.call(magic_card: magic_card, card_data: token)
    end
  end
end
