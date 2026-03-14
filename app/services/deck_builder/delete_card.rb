module DeckBuilder
  class DeleteCard < Service
    def initialize(deck:, collection_magic_card_id:)
      @deck = deck
      @card_id = collection_magic_card_id
    end

    def call
      card = @deck.collection_magic_cards.find(@card_id)

      result = CollectionRecord::CreateOrUpdate.call(
        params: {
          collection_id: @deck.id,
          magic_card_id: card.magic_card_id,
          card_uuid: card.card_uuid,
          quantity: [card.quantity - 1, 0].max,
          foil_quantity: card.foil_quantity,
          proxy_quantity: card.proxy_quantity,
          proxy_foil_quantity: card.proxy_foil_quantity
        }
      )

      { success: true, message: "#{result[:name]} removed from collection" }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found in deck' }
    end
  end
end
