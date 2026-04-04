module DeckBuilder
  class ExportDeck < Service
    def initialize(deck:)
      @deck = deck
    end

    def call
      cards = @deck.collection_magic_cards
                   .includes(magic_card: :boxset)

      all_cards = cards.select(&:commander?) +
                  cards.reject { |c| c.commander? || c.board_type == 'sideboard' } +
                  cards.select { |c| c.board_type == 'sideboard' }

      all_cards.map { |c| format_card(c) }.join("\n")
    end

    private

    def format_card(card)
      name = card.magic_card.name
      set_code = card.magic_card.boxset&.code&.upcase
      number = card.magic_card.card_number
      base = "#{card.display_quantity} #{name}"

      set_code.present? && number.present? ? "#{base} (#{set_code}) #{number}" : base
    end
  end
end
