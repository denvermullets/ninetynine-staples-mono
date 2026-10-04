# A card as a search result shows it: enough to recognise it in a list and pick one. The client fetches
# the full card object for the ones it keeps through POST /api/v1/cards/batch.
#
# Serialize a page of results with .many - the sets load in one query. new(card) is for one card.
class Api::V1::CardSummarySerializer
  def self.many(cards)
    cards = cards.to_a
    ActiveRecord::Associations::Preloader.new(records: cards, associations: :boxset).call
    cards.map { |card| new(card).as_json }
  end

  def initialize(card)
    @card = card
  end

  def as_json(*)
    {
      card_uuid: @card.card_uuid,
      oracle_id: @card.scryfall_oracle_id,
      name: @card.name,
      set_code: @card.boxset&.code,
      type_line: @card.card_type,
      mana_cost: @card.mana_cost,
      is_token: @card.is_token,
      image_art_crop: Api::V1::DeckSummarySerializer.image_url(@card.art_crop),
      image_normal: Api::V1::DeckSummarySerializer.image_url(@card.image_medium)
    }
  end
end
