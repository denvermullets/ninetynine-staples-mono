module DeckBuilder
  class UpdateStaged < Service
    QUANTITY_TYPES = %i[regular foil proxy proxy_foil].freeze

    def initialize(deck:, card_id:, quantities:)
      @deck = deck
      @card = deck.collection_magic_cards.staged.find(card_id)
      @quantities = normalize_quantities(quantities)
    end

    def call
      return remove_card if total_zero?
      return validation_error('Quantities cannot be negative') if any_negative?

      validate_source_availability if @card.source_collection_id
      return @validation_error if @validation_error

      update_card
      { success: true, card_name: @card.magic_card.name }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found' }
    end

    private

    def normalize_quantities(params)
      {
        regular: params[:regular].to_i,
        foil: params[:foil].to_i,
        proxy: params[:proxy].to_i,
        proxy_foil: params[:proxy_foil].to_i
      }
    end

    def total_zero?
      @quantities.values.sum.zero?
    end

    def any_negative?
      @quantities.values.any?(&:negative?)
    end

    def remove_card
      card_name = @card.magic_card.name
      @card.destroy!
      { success: true, card_name: card_name, removed: true }
    end

    def validation_error(message)
      { success: false, error: message }
    end

    def validate_source_availability
      source = find_source
      return @validation_error = validation_error('Source collection not found') unless source

      available = StagedQuantities.calculate_available(source: source, exclude_card_id: @card.id)

      QUANTITY_TYPES.each do |type|
        next unless @quantities[type] > available[type]

        @validation_error = validation_error("Only #{available[type]} #{type.to_s.humanize.downcase} available")
        break
      end
    end

    def find_source
      CollectionMagicCard.find_by(
        collection_id: @card.source_collection_id,
        magic_card_id: @card.magic_card_id,
        staged: false,
        needed: false
      )
    end

    def update_card
      @card.update!(
        staged_quantity: @quantities[:regular],
        staged_foil_quantity: @quantities[:foil],
        staged_proxy_quantity: @quantities[:proxy],
        staged_proxy_foil_quantity: @quantities[:proxy_foil]
      )
    end
  end
end
