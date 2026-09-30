module CollectionImporter
  class Archidekt < Service
    include CollectionRecord::PriceCalculator

    COUNT_KEYS = %i[foil_quantity proxy_quantity proxy_foil_quantity].freeze

    def initialize(row_data:, collection:, skip_existing: false)
      @row_data = row_data.symbolize_keys
      @collection = collection
      @skip_existing = skip_existing
    end

    def call
      @magic_card = MagicCardIdentifier.find_by(scryfall_id: @row_data[:scryfall_id])&.magic_card
      return { action: :skipped, name: @row_data[:name] } unless @magic_card

      changes = quantity_changes

      return { action: :skipped, name: @magic_card.name } if @skip_existing && card_exists_in_collection?

      collection_card = find_or_initialize_collection_card
      collection_card.update!(changes.to_h { |column, change| [column, collection_card[column] + change] })
      update_totals(changes)

      { action: :success, name: @magic_card.name }
    end

    private

    def update_totals(changes)
      CollectionRecord::UpdateTotals.call(
        collection: @collection,
        changes: changes.merge(
          real_price: calculate_price_change(changes[:quantity], changes[:foil_quantity]),
          proxy_price: (changes[:proxy_quantity] * @magic_card.proxy_normal_price) +
                       (changes[:proxy_foil_quantity] * @magic_card.proxy_foil_price)
        )
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

    # our export carries a column per finish; an Archidekt row is one Quantity of one Finish
    def quantity_changes
      return column_changes if COUNT_KEYS.any? { |key| @row_data.key?(key) }

      quantity = @row_data[:quantity].to_i
      foil = @row_data[:finish]&.downcase&.include?('foil')
      { quantity: foil ? 0 : quantity, foil_quantity: foil ? quantity : 0, proxy_quantity: 0, proxy_foil_quantity: 0 }
    end

    def column_changes
      [:quantity, *COUNT_KEYS].index_with { |key| [@row_data[key].to_i, 0].max }
    end
  end
end
