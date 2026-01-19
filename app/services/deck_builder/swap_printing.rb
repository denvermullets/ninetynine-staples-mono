module DeckBuilder
  class SwapPrinting < Service
    def initialize(deck:, collection_magic_card_id:, new_magic_card_id:)
      @deck = deck
      @deck_card = deck.collection_magic_cards.staged.planned.find(collection_magic_card_id)
      @new_magic_card = MagicCard.find(new_magic_card_id)
    end

    def call
      return { success: false, error: 'Card not found' } unless @deck_card
      return { success: false, error: 'New printing not found' } unless @new_magic_card
      return { success: false, error: 'Already using this printing' } if same_printing?
      return { success: false, error: 'Not the same card' } unless same_oracle_id?

      ActiveRecord::Base.transaction do
        update_deck_card
      end

      { success: true, card_name: @new_magic_card.name }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found' }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def same_printing?
      @deck_card.magic_card_id == @new_magic_card.id
    end

    def same_oracle_id?
      @deck_card.magic_card.scryfall_oracle_id == @new_magic_card.scryfall_oracle_id
    end

    def update_deck_card
      @deck_card.update!(magic_card_id: @new_magic_card.id)
    end
  end
end
