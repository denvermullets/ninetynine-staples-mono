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
      return { success: false, error: 'Card not found' } unless @deck_card
      return { success: false, error: 'Already using this source' } if same_source_and_printing?

      if @new_source_id
        validation = validate_new_source
        return validation unless validation[:success]
      end

      ActiveRecord::Base.transaction do
        updates = { source_collection_id: @new_source_id }
        updates[:magic_card_id] = @new_magic_card_id if @new_magic_card_id
        @deck_card.update!(updates)
      end

      source_name = @new_source_id ? Collection.find(@new_source_id).name : 'planned'
      { success: true, card_name: @deck_card.magic_card.name, source_name: source_name }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found' }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def same_source_and_printing?
      same_source = @deck_card.source_collection_id == @new_source_id&.to_i
      same_printing = @new_magic_card_id.nil? || @deck_card.magic_card_id == @new_magic_card_id
      same_source && same_printing
    end

    def validate_new_source
      target_magic_card_id = @new_magic_card_id || @magic_card.id

      source_cmc = CollectionMagicCard.find_by(
        collection_id: @new_source_id,
        magic_card_id: target_magic_card_id,
        staged: false,
        needed: false
      )

      return { success: false, error: 'Card not found in source collection' } unless source_cmc

      total_available = calculate_total_available(source_cmc, target_magic_card_id)
      total_needed = @deck_card.total_staged

      return { success: false, error: "Only #{total_available} copies available" } if total_needed > total_available

      { success: true }
    end

    def calculate_total_available(cmc, magic_card_id)
      already_staged = CollectionMagicCard
        .staged
        .where(source_collection_id: cmc.collection_id, magic_card_id: magic_card_id)
        .where.not(id: @deck_card.id)

      staged_total = already_staged.sum(:staged_quantity) +
                     already_staged.sum(:staged_foil_quantity) +
                     already_staged.sum(:staged_proxy_quantity) +
                     already_staged.sum(:staged_proxy_foil_quantity)

      cmc.quantity + cmc.foil_quantity + (cmc.proxy_quantity || 0) + (cmc.proxy_foil_quantity || 0) - staged_total
    end
  end
end
