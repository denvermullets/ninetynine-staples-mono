module CollectionImporter
  class Archidekt < Service
    include CollectionRecord::PriceCalculator

    def initialize(row_data:, collection:, skip_existing: false)
      @row_data = row_data.symbolize_keys
      @collection = collection
      @skip_existing = skip_existing
    end

    def call
      @magic_card = MagicCardIdentifier.find_by(scryfall_id: @row_data[:scryfall_id])&.magic_card
      return { action: :skipped, name: @row_data[:name] } unless @magic_card

      normal_change, foil_change = quantity_changes

      return { action: :skipped, name: @magic_card.name } if @skip_existing && card_exists_in_collection?

      collection_card = find_or_initialize_collection_card
      collection_card.update!(
        quantity: collection_card.quantity + normal_change,
        foil_quantity: collection_card.foil_quantity + foil_change
      )
      update_totals(normal_change, foil_change)

      { action: :success, name: @magic_card.name }
    end

    private

    def update_totals(normal_change, foil_change)
      CollectionRecord::UpdateTotals.call(
        collection: @collection,
        changes: {
          quantity: normal_change, foil_quantity: foil_change,
          proxy_quantity: 0, proxy_foil_quantity: 0,
          real_price: calculate_price_change(normal_change, foil_change), proxy_price: 0
        }
      )
    end

    def card_exists_in_collection?
      CollectionMagicCard.exists?(
        collection: @collection,
        magic_card: @magic_card
      )
    end

    def find_or_initialize_collection_card
      CollectionMagicCard.find_or_initialize_by(
        collection: @collection,
        magic_card: @magic_card,
        card_uuid: @magic_card.card_uuid,
        board_type: 'mainboard'
      )
    end

    def quantity_changes
      quantity = @row_data[:quantity].to_i
      if @row_data[:finish]&.downcase&.include?('foil')
        [0, quantity]
      else
        [quantity, 0]
      end
    end
  end
end
