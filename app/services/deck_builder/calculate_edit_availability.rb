module DeckBuilder
  class CalculateEditAvailability < Service
    def initialize(card:)
      @card = card
    end

    def call
      return {} unless @card.source_collection_id

      source = find_source
      return {} unless source

      StagedQuantities.calculate_available(source: source, exclude_card_id: @card.id)
    end

    private

    def find_source
      CollectionMagicCard.find_by(
        collection_id: @card.source_collection_id,
        magic_card_id: @card.magic_card_id,
        staged: false,
        needed: false
      )
    end
  end
end
