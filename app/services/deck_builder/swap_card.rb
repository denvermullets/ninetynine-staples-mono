module DeckBuilder
  class SwapCard < Service
    def initialize(deck:, collection_magic_card_id:, source_collection_id: nil)
      @deck = deck
      @deck_card = deck.collection_magic_cards.needed.find(collection_magic_card_id)
      @source_collection_id = source_collection_id
      @magic_card = @deck_card.magic_card
    end

    def call
      source = find_best_source
      return { success: false, error: 'No available copies found' } unless source

      ActiveRecord::Base.transaction do
        reduce_source(source)
        update_deck_card
        update_collection_totals(source.collection)
        update_collection_totals(@deck)
      end

      { success: true, card_name: @magic_card.name }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found' }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def find_best_source
      owned_copies = @magic_card.user_owned_copies(@deck.user)

      if @source_collection_id
        owned_copies.find { |c| c.collection_id == @source_collection_id.to_i }
      else
        owned_copies.max_by { |c| c.quantity + c.foil_quantity }
      end
    end

    def reduce_source(source)
      qty_needed = @deck_card.quantity
      foil_needed = @deck_card.foil_quantity

      unless source.quantity >= qty_needed && source.foil_quantity >= foil_needed
        raise "Not enough copies in #{source.collection.name}"
      end

      new_qty = source.quantity - qty_needed
      new_foil = source.foil_quantity - foil_needed

      if new_qty.zero? && new_foil.zero? &&
         source.proxy_quantity.zero? && source.proxy_foil_quantity.zero?
        source.destroy!
      else
        source.update!(quantity: new_qty, foil_quantity: new_foil)
      end
    end

    def update_deck_card
      @deck_card.update!(needed: false)
    end

    def update_collection_totals(collection)
      collection.update!(
        total_quantity: collection.collection_magic_cards.finalized.owned.sum(:quantity),
        total_foil_quantity: collection.collection_magic_cards.finalized.owned.sum(:foil_quantity),
        total_value: calculate_total_value(collection)
      )
    end

    def calculate_total_value(collection)
      collection.collection_magic_cards.finalized.owned.sum do |cmc|
        (cmc.quantity * cmc.magic_card.normal_price.to_f) +
          (cmc.foil_quantity * cmc.magic_card.foil_price.to_f)
      end
    end
  end
end
