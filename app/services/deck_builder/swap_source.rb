module DeckBuilder
  class SwapSource < Service
    def initialize(deck:, collection_magic_card_id:, new_source_collection_id:, new_magic_card_id: nil)
      @deck = deck
      @deck_card = deck.collection_magic_cards.staged.find(collection_magic_card_id)
      @new_source_id = new_source_collection_id.presence
      @new_magic_card_id = new_magic_card_id.presence&.to_i
      @magic_card = @deck_card.magic_card
    end

    def call
      return error('Card not found') unless @deck_card
      return error('Already using this source') if same_source_and_printing?

      validation = validate_new_source
      return validation unless validation[:success]

      perform_swap
      success_result
    rescue ActiveRecord::RecordNotFound
      error('Card not found')
    rescue StandardError => e
      error(e.message)
    end

    private

    def error(message)
      { success: false, error: message }
    end

    def same_source_and_printing?
      same_source = @deck_card.source_collection_id == @new_source_id&.to_i
      same_printing = @new_magic_card_id.nil? || @deck_card.magic_card_id == @new_magic_card_id
      same_source && same_printing
    end

    def validate_new_source
      return { success: true } unless @new_source_id

      source = find_source_card
      return error('Card not found in source collection') unless source

      available = calculate_available(source)
      needed = @deck_card.total_staged

      return error("Only #{available} copies available") if needed > available

      { success: true }
    end

    def find_source_card
      CollectionMagicCard.find_by(
        collection_id: @new_source_id,
        magic_card_id: target_magic_card_id,
        staged: false,
        needed: false
      )
    end

    def target_magic_card_id
      @new_magic_card_id || @magic_card.id
    end

    def calculate_available(source)
      total = source.quantity + source.foil_quantity +
              (source.proxy_quantity || 0) + (source.proxy_foil_quantity || 0)

      staged = StagedQuantities.total_staged(
        source_collection_id: source.collection_id,
        magic_card_id: target_magic_card_id,
        exclude_card_id: @deck_card.id
      )

      total - staged
    end

    def perform_swap
      ActiveRecord::Base.transaction do
        updates = { source_collection_id: @new_source_id }
        updates[:magic_card_id] = @new_magic_card_id if @new_magic_card_id
        @deck_card.update!(updates)
      end
    end

    def success_result
      source_name = @new_source_id ? Collection.find(@new_source_id).name : 'planned'
      { success: true, card_name: @deck_card.magic_card.name, source_name: source_name }
    end
  end
end
