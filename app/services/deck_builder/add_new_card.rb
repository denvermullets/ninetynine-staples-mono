module DeckBuilder
  class AddNewCard < Service
    CARD_TYPES = %w[regular foil proxy foil_proxy].freeze

    def initialize(deck:, magic_card_id:, card_type:, quantity: 1)
      @deck = deck
      @magic_card = MagicCard.find(magic_card_id)
      @card_type = card_type.to_s
      @quantity = [quantity.to_i, 1].max
    end

    def call
      return error_result('Invalid card type') unless CARD_TYPES.include?(@card_type)
      return error_result('No quantity specified') if @quantity.zero?

      ActiveRecord::Base.transaction do
        card = find_or_create_owned_card
        update_quantity(card)

        { success: true, card_name: @magic_card.name, card: card }
      end
    rescue ActiveRecord::RecordNotFound
      error_result('Card not found')
    rescue StandardError => e
      error_result(e.message)
    end

    private

    def find_or_create_owned_card
      existing = @deck.collection_magic_cards.find_by(
        magic_card_id: @magic_card.id,
        staged: false,
        needed: false
      )

      return existing if existing

      @deck.collection_magic_cards.create!(
        magic_card: @magic_card,
        card_uuid: @magic_card.card_uuid,
        staged: false,
        needed: false,
        quantity: 0,
        foil_quantity: 0,
        proxy_quantity: 0,
        proxy_foil_quantity: 0,
        staged_quantity: 0,
        staged_foil_quantity: 0
      )
    end

    def update_quantity(card)
      case @card_type
      when 'regular'
        card.quantity += @quantity
      when 'foil'
        card.foil_quantity += @quantity
      when 'proxy'
        card.proxy_quantity += @quantity
      when 'foil_proxy'
        card.proxy_foil_quantity += @quantity
      end
      card.save!
    end

    def error_result(message)
      { success: false, error: message }
    end
  end
end
