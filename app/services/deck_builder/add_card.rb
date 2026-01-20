module DeckBuilder
  class AddCard < Service
    CARD_TYPES = %w[regular foil proxy proxy_foil].freeze
    STAGED_COLUMN_MAP = {
      'regular' => :staged_quantity,
      'foil' => :staged_foil_quantity,
      'proxy' => :staged_proxy_quantity,
      'proxy_foil' => :staged_proxy_foil_quantity
    }.freeze
    SOURCE_COLUMN_MAP = {
      'regular' => :quantity,
      'foil' => :foil_quantity,
      'proxy' => :proxy_quantity,
      'proxy_foil' => :proxy_foil_quantity
    }.freeze

    def initialize(deck:, magic_card_id:, source_collection_id: nil, card_type: 'regular', quantity: 1)
      @deck = deck
      @magic_card = MagicCard.find(magic_card_id)
      @source_collection_id = source_collection_id.presence
      @card_type = card_type.to_s
      @quantity = [quantity.to_i, 0].max
    end

    def call
      return error_result('Invalid card type') unless CARD_TYPES.include?(@card_type)
      return error_result('No quantity specified') if @quantity.zero?

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
      @source = CollectionMagicCard.find_by(
        collection_id: @source_collection_id,
        magic_card_id: @magic_card.id,
        staged: false,
        needed: false
      )

      return error_result('Card not found in source collection') unless @source

      source_column = SOURCE_COLUMN_MAP[@card_type]
      staged_column = STAGED_COLUMN_MAP[@card_type]

      source_qty = @source.send(source_column) || 0
      already_staged = already_staged_qty(staged_column)
      available = source_qty - already_staged

      return error_result("Only #{available} #{@card_type.humanize.downcase} available") if @quantity > available

      { success: true }
    end

    def already_staged_qty(column)
      CollectionMagicCard
        .staged
        .where(source_collection_id: @source_collection_id, magic_card_id: @magic_card.id)
        .sum(column)
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
        staged_proxy_quantity: 0,
        staged_proxy_foil_quantity: 0,
        quantity: 0,
        foil_quantity: 0,
        proxy_quantity: 0,
        proxy_foil_quantity: 0
      )
    end

    def update_staged_quantities(card)
      column = STAGED_COLUMN_MAP[@card_type]
      card.send("#{column}=", card.send(column) + @quantity)
      card.save!
    end

    def error_result(message)
      { success: false, error: message }
    end
  end
end
