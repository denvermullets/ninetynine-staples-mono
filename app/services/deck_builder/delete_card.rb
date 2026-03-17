module DeckBuilder
  class DeleteCard < Service
    def initialize(deck:, collection_magic_card_id:)
      @deck = deck
      @card_id = collection_magic_card_id
    end

    def call
      card = @deck.collection_magic_cards.find(@card_id)
      card_name = card.magic_card.name
      oracle_id = card.magic_card.scryfall_oracle_id

      card.destroy!

      { success: true, message: "#{card_name} deleted from collection",
        removed_oracle_id: oracle_id }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found in deck' }
    end
  end
end
