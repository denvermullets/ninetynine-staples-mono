module DeckBuilder
  class RemoveCard < Service
    def initialize(deck:, collection_magic_card_id:)
      @deck = deck
      @card_id = collection_magic_card_id
    end

    def call
      card = @deck.collection_magic_cards.find(@card_id)

      if card.staged?
        card.destroy!
        { success: true, message: 'Card removed from deck' }
      elsif card.needed?
        card.destroy!
        { success: true, message: 'Needed card removed from deck' }
      else
        { success: false, error: 'Cannot remove finalized cards. Use transfer instead.' }
      end
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found in deck' }
    end
  end
end
