# frozen_string_literal: true

module CardScannerSerialization
  extend ActiveSupport::Concern

  private

  def serialize_results(results)
    results.map { |result| serialize_card_result(result) }
  end

  def serialize_card_result(result)
    card = result[:card]
    owned = result[:owned] || {}
    {
      card: card_json(card),
      owned: owned_json(owned)
    }
  end

  def card_json(card)
    {
      id: card.id,
      name: card.name,
      card_uuid: card.card_uuid,
      card_number: card.card_number,
      boxset_name: card.boxset&.name,
      boxset_code: card.boxset&.code,
      image_small: card.image_small,
      image_large: card.image_large,
      normal_price: card.normal_price.to_f,
      foil_price: card.foil_price.to_f,
      has_foil: card.foil_available?,
      has_non_foil: card.non_foil_available?
    }
  end

  def owned_json(owned)
    {
      quantity: owned[:quantity] || 0,
      foil_quantity: owned[:foil_quantity] || 0,
      proxy_quantity: owned[:proxy_quantity] || 0,
      proxy_foil_quantity: owned[:proxy_foil_quantity] || 0
    }
  end
end
