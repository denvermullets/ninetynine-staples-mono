module DeckBuilder
  class AddCard < Service
    def initialize(deck:, magic_card_id:, source_collection_id: nil, quantity: 1, foil_quantity: 0)
      @deck = deck
      @magic_card = MagicCard.find(magic_card_id)
      @source_collection_id = source_collection_id.presence
      @quantity = [quantity.to_i, 0].max
      @foil_quantity = [foil_quantity.to_i, 0].max
    end

    def call
      return error_result('No quantity specified') if @quantity.zero? && @foil_quantity.zero?

      ActiveRecord::Base.transaction do
        if @source_collection_id
          validation = validate_source_availability
          return validation unless validation[:success]
        end

        staged_card = find_or_create_staged_card
        update_staged_quantities(staged_card)

        { success: true, card_name: @magic_card.name, card: staged_card }
      end
    rescue ActiveRecord::RecordNotFound
      error_result('Card or collection not found')
    rescue StandardError => e
      error_result(e.message)
    end

    private

    def validate_source_availability
      source = CollectionMagicCard.find_by(
        collection_id: @source_collection_id,
        magic_card_id: @magic_card.id,
        staged: false,
        needed: false
      )

      return error_result('Card not found in source collection') unless source

      available_qty = source.quantity - already_staged_qty(:staged_quantity)
      available_foil = source.foil_quantity - already_staged_qty(:staged_foil_quantity)

      return error_result("Only #{available_qty} regular copies available") if @quantity > available_qty

      return error_result("Only #{available_foil} foil copies available") if @foil_quantity > available_foil

      { success: true }
    end

    def already_staged_qty(type)
      CollectionMagicCard
        .staged
        .where(source_collection_id: @source_collection_id, magic_card_id: @magic_card.id)
        .sum(type)
    end

    def find_or_create_staged_card
      existing = @deck.collection_magic_cards.find_by(
        magic_card_id: @magic_card.id,
        source_collection_id: @source_collection_id,
        staged: true
      )

      return existing if existing

      @deck.collection_magic_cards.create!(
        magic_card: @magic_card,
        card_uuid: @magic_card.card_uuid,
        source_collection_id: @source_collection_id,
        staged: true,
        staged_quantity: 0,
        staged_foil_quantity: 0,
        quantity: 0,
        foil_quantity: 0,
        proxy_quantity: 0,
        proxy_foil_quantity: 0
      )
    end

    def update_staged_quantities(card)
      card.staged_quantity += @quantity
      card.staged_foil_quantity += @foil_quantity
      card.save!
    end

    def error_result(message)
      { success: false, error: message }
    end
  end
end
