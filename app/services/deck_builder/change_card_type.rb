# Changes a finalized card's type (regular, foil, proxy, proxy_foil).
# Moves the card's total quantity into the target type and zeros the rest.
# Recalculates deck totals since different types have different prices.
module DeckBuilder
  class ChangeCardType < Service
    VALID_TYPES = %w[regular foil proxy proxy_foil].freeze
    QUANTITY_FIELDS = %i[quantity foil_quantity proxy_quantity proxy_foil_quantity].freeze
    TYPE_TO_FIELD = {
      'regular' => :quantity, 'foil' => :foil_quantity,
      'proxy' => :proxy_quantity, 'proxy_foil' => :proxy_foil_quantity
    }.freeze

    def initialize(deck:, card_id:, card_type:)
      @deck = deck
      @deck_card = deck.collection_magic_cards.find(card_id)
      @card_type = card_type
    end

    def call
      return { success: false, error: 'Invalid card type' } unless VALID_TYPES.include?(@card_type)
      return { success: false, error: 'Already this type' } if already_target_type?

      ActiveRecord::Base.transaction do
        update_quantities
        Collections::UpdateTotals.call(collection: @deck) unless @deck_card.staged?
      end

      { success: true, card_name: @deck_card.magic_card.name, card_type: @card_type }
    rescue ActiveRecord::RecordNotFound
      { success: false, error: 'Card not found' }
    rescue StandardError => e
      { success: false, error: e.message }
    end

    private

    def update_quantities
      total = @deck_card.display_quantity
      target_field = TYPE_TO_FIELD[@card_type]
      attrs = QUANTITY_FIELDS.to_h { |f| [f, f == target_field ? total : 0] }
      @deck_card.update!(attrs)
    end

    def already_target_type?
      target_field = TYPE_TO_FIELD[@card_type]
      @deck_card.send(target_field).positive? &&
        (QUANTITY_FIELDS - [target_field]).all? { |f| @deck_card.send(f).zero? }
    end
  end
end
