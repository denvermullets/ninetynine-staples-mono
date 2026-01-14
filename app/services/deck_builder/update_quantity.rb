module DeckBuilder
  class UpdateQuantity < Service
    def initialize(deck:, collection_magic_card_id:, quantity:, foil_quantity:)
      @deck = deck
      @card = deck.collection_magic_cards.find(collection_magic_card_id)
      @new_quantity = [quantity.to_i, 0].max
      @new_foil_quantity = [foil_quantity.to_i, 0].max
    end

    def call
      return error_result('Quantity must be at least 1') if zero_quantity?

      ActiveRecord::Base.transaction do
        return validate_and_update_staged if staged_from_collection?

        update_card_quantities
        success_result
      end
    rescue ActiveRecord::RecordNotFound
      error_result('Card not found')
    rescue StandardError => e
      error_result(e.message)
    end

    private

    def zero_quantity?
      @new_quantity.zero? && @new_foil_quantity.zero?
    end

    def staged_from_collection?
      @card.staged? && @card.from_owned_collection?
    end

    def validate_and_update_staged
      validation = validate_source_availability
      return validation unless validation[:success]

      update_card_quantities
      success_result
    end

    def validate_source_availability
      source = find_source_card
      return error_result('Source collection card not found') unless source

      check_availability(source)
    end

    def find_source_card
      CollectionMagicCard.find_by(
        collection_id: @card.source_collection_id,
        magic_card_id: @card.magic_card_id,
        staged: false,
        needed: false
      )
    end

    def check_availability(source)
      available = calculate_available(source)

      return error_result("Only #{available[:regular]} copies available") if @new_quantity > available[:regular]

      return error_result("Only #{available[:foil]} foil copies available") if @new_foil_quantity > available[:foil]

      { success: true }
    end

    def calculate_available(source)
      other_staged = other_staged_quantities
      {
        regular: source.quantity + (source.proxy_quantity || 0) - other_staged[:regular],
        foil: source.foil_quantity + (source.proxy_foil_quantity || 0) - other_staged[:foil]
      }
    end

    def other_staged_quantities
      base_query = CollectionMagicCard
                   .staged
                   .where(source_collection_id: @card.source_collection_id)
                   .where(magic_card_id: @card.magic_card_id)
                   .where.not(id: @card.id)

      {
        regular: base_query.sum(:staged_quantity),
        foil: base_query.sum(:staged_foil_quantity)
      }
    end

    def update_card_quantities
      if @card.staged?
        @card.update!(staged_quantity: @new_quantity, staged_foil_quantity: @new_foil_quantity)
      else
        @card.update!(quantity: @new_quantity, foil_quantity: @new_foil_quantity)
      end
    end

    def success_result
      { success: true, card_name: @card.magic_card.name, card: @card }
    end

    def error_result(message)
      { success: false, error: message }
    end
  end
end
