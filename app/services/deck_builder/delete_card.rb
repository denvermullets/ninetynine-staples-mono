module DeckBuilder
  class DeleteCard < Service
    include CollectionRecord::PriceCalculator

    def initialize(deck:, collection_magic_card_id:)
      @deck = deck
      @card_id = collection_magic_card_id
    end

    def call
      card = @deck.collection_magic_cards.find(@card_id)
      @magic_card = card.magic_card

      real_price = calculate_real_price(card)
      proxy_price = calculate_proxy_price(card)

      card.destroy!

      CollectionRecord::UpdateTotals.call(
        collection: @deck,
        changes: {
          quantity: -card.quantity,
          foil_quantity: -card.foil_quantity,
          proxy_quantity: -card.proxy_quantity,
          proxy_foil_quantity: -card.proxy_foil_quantity,
          real_price: -real_price,
          proxy_price: -proxy_price
        }
      )

      { success: true, message: "#{@magic_card.name} deleted from collection" }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found in deck' }
    end
  end
end
