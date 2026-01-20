module DeckBuilder
  class StagedQuantities < Service
    QUANTITY_TYPES = %i[regular foil proxy proxy_foil].freeze

    def initialize(source_collection_id:, magic_card_id:, exclude_card_id: nil)
      @source_collection_id = source_collection_id
      @magic_card_id = magic_card_id
      @exclude_card_id = exclude_card_id
    end

    def call
      {
        regular: staged_scope.sum(:staged_quantity),
        foil: staged_scope.sum(:staged_foil_quantity),
        proxy: staged_scope.sum(:staged_proxy_quantity),
        proxy_foil: staged_scope.sum(:staged_proxy_foil_quantity)
      }
    end

    def self.calculate_available(source:, exclude_card_id: nil)
      staged = call(
        source_collection_id: source.collection_id,
        magic_card_id: source.magic_card_id,
        exclude_card_id: exclude_card_id
      )

      {
        regular: [source.quantity - staged[:regular], 0].max,
        foil: [source.foil_quantity - staged[:foil], 0].max,
        proxy: [(source.proxy_quantity || 0) - staged[:proxy], 0].max,
        proxy_foil: [(source.proxy_foil_quantity || 0) - staged[:proxy_foil], 0].max
      }
    end

    def self.total_staged(source_collection_id:, magic_card_id:, exclude_card_id: nil)
      staged = call(
        source_collection_id: source_collection_id,
        magic_card_id: magic_card_id,
        exclude_card_id: exclude_card_id
      )
      staged.values.sum
    end

    private

    def staged_scope
      scope = CollectionMagicCard.staged.where(
        source_collection_id: @source_collection_id,
        magic_card_id: @magic_card_id
      )
      scope = scope.where.not(id: @exclude_card_id) if @exclude_card_id
      scope
    end
  end
end
