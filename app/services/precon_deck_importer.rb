class PreconDeckImporter < Service
  include CollectionRecord::PriceCalculator

  def initialize(precon_deck:, collection:, include_tokens: false)
    @precon_deck = precon_deck
    @collection = collection
    @include_tokens = include_tokens
  end

  def call
    cards_count = 0

    ActiveRecord::Base.transaction do
      cards_to_import.includes(:magic_card).find_each do |pdc|
        add_card_to_collection(pdc)
        cards_count += 1
      end
    end

    { action: :success, deck_name: @precon_deck.name, cards_imported: cards_count }
  end

  private

  def cards_to_import
    scope = @precon_deck.precon_deck_cards
    scope = scope.where.not(board_type: 'tokens') unless @include_tokens
    scope
  end

  def add_card_to_collection(precon_deck_card)
    @magic_card = precon_deck_card.magic_card
    collection_card = find_or_initialize_collection_card
    normal_change, foil_change = quantity_changes(precon_deck_card)

    update_collection_card(collection_card, normal_change, foil_change)
    update_collection_totals(normal_change, foil_change)
  end

  def find_or_initialize_collection_card
    CollectionMagicCard.find_or_initialize_by(
      collection: @collection,
      magic_card: @magic_card,
      card_uuid: @magic_card.card_uuid
    )
  end

  def quantity_changes(precon_deck_card)
    if precon_deck_card.is_foil
      [0, precon_deck_card.quantity]
    else
      [precon_deck_card.quantity, 0]
    end
  end

  def update_collection_card(collection_card, normal_change, foil_change)
    collection_card.update!(
      quantity: collection_card.quantity + normal_change,
      foil_quantity: collection_card.foil_quantity + foil_change
    )
  end

  def update_collection_totals(normal_change, foil_change)
    CollectionRecord::UpdateTotals.call(
      collection: @collection,
      changes: {
        quantity: normal_change,
        foil_quantity: foil_change,
        proxy_quantity: 0,
        proxy_foil_quantity: 0,
        real_price: calculate_price_change(normal_change, foil_change),
        proxy_price: 0
      }
    )
  end
end
