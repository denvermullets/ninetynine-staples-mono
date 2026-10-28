module DeckBuilder
  # Swaps a card's printing (e.g. switching from M21 to MH2 version) for both
  # staged and finalized cards. Useful when a user imported or finalized the
  # wrong version and wants to correct it without removing/re-adding the card.
  class SwapPrinting < Service
    def initialize(deck:, collection_magic_card_id:, new_magic_card_id:)
      @deck = deck
      @deck_card = deck.collection_magic_cards.find(collection_magic_card_id)
      @new_magic_card = MagicCard.find(new_magic_card_id)
    end

    def call
      error = validation_error
      return { success: false, error: error } if error

      ActiveRecord::Base.transaction do
        update_deck_card

        # Finalized cards contribute to the deck's aggregate totals (total_value, etc.).
        # Different printings can have different prices, so we recalculate after the swap.
        # Staged cards don't affect collection totals so we skip the recalc for those.
        recalculate_totals unless @deck_card.staged?
      end

      { success: true, card_name: @new_magic_card.name }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found' }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def validation_error
      return 'Card not found' unless @deck_card
      return 'New printing not found' unless @new_magic_card
      return 'Already using this printing' if same_printing?
      return 'Not the same card' unless same_oracle_id?

      source_printing_error
    end

    def same_printing?
      @deck_card.magic_card_id == @new_magic_card.id
    end

    def same_oracle_id?
      @deck_card.magic_card.scryfall_oracle_id == @new_magic_card.scryfall_oracle_id
    end

    # A staged row pulled from a collection is finalized by finding that exact printing in the source,
    # so the swap can only land on a printing the source holds enough copies of
    def source_printing_error
      return unless @deck_card.from_owned_collection?

      source = CollectionMagicCard.find_by(
        collection_id: @deck_card.source_collection_id, magic_card_id: @new_magic_card.id,
        staged: false, needed: false
      )
      return "#{source_name} doesn't have that printing - change the source to switch printings" unless source

      available = StagedQuantities.calculate_available(source: source, exclude_card_id: @deck_card.id)
      return if enough_copies?(available)

      "#{source_name} doesn't have enough copies of that printing"
    end

    def enough_copies?(available)
      @deck_card.staged_quantity <= available[:regular] &&
        @deck_card.staged_foil_quantity <= available[:foil] &&
        @deck_card.staged_proxy_quantity <= available[:proxy] &&
        @deck_card.staged_proxy_foil_quantity <= available[:proxy_foil]
    end

    def source_name = @deck_card.source_collection.name

    def update_deck_card
      @deck_card.update!(magic_card_id: @new_magic_card.id, card_uuid: @new_magic_card.card_uuid)
    end

    def recalculate_totals
      Collections::UpdateTotals.call(collection: @deck)
    end
  end
end
