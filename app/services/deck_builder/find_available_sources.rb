module DeckBuilder
  class FindAvailableSources < Service
    def initialize(card:, user:, deck:)
      @card = card
      @user = user
      @deck = deck
      @needed = SourceShortfall.staged_on(card)
    end

    def call
      user_copies.filter_map { |cmc| build_source_result(cmc) }
    end

    private

    def user_copies
      CollectionMagicCard
        .joins(:collection, :magic_card)
        .includes(:collection, magic_card: :boxset)
        .where(collections: { user_id: @user.id })
        .where(magic_card_id: printing_ids, staged: false, needed: false)
        .where.not(collection_id: @deck.id)
    end

    def printing_ids
      @printing_ids ||= MagicCard.where(scryfall_oracle_id: oracle_id).pluck(:id)
    end

    def oracle_id
      @card.magic_card.scryfall_oracle_id
    end

    # a source is offered only if it covers the row type for type, the same check the swap and Finalize make
    def build_source_result(cmc)
      available = StagedQuantities.calculate_available(source: cmc, exclude_card_id: @card.id)
      return if SourceShortfall.first(needed: @needed, available: available)

      {
        collection_id: cmc.collection_id,
        collection_name: cmc.collection.name,
        magic_card: cmc.magic_card,
        **extract_quantities(cmc),
        total_available: available.values.sum,
        is_current: current_source?(cmc)
      }
    end

    def extract_quantities(cmc)
      {
        regular: cmc.quantity,
        foil: cmc.foil_quantity,
        proxy: cmc.proxy_quantity || 0,
        proxy_foil: cmc.proxy_foil_quantity || 0
      }
    end

    def current_source?(cmc)
      cmc.collection_id == @card.source_collection_id && cmc.magic_card_id == @card.magic_card_id
    end
  end
end
