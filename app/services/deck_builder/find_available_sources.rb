module DeckBuilder
  class FindAvailableSources < Service
    def initialize(card:, user:, deck:)
      @card = card
      @user = user
      @deck = deck
      @total_needed = card.total_staged
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

    def build_source_result(cmc)
      quantities = extract_quantities(cmc)
      already_staged = StagedQuantities.total_staged(
        source_collection_id: cmc.collection_id,
        magic_card_id: cmc.magic_card_id,
        exclude_card_id: @card.id
      )

      total_available = quantities.values.sum - already_staged
      return if total_available < @total_needed

      {
        collection_id: cmc.collection_id,
        collection_name: cmc.collection.name,
        magic_card: cmc.magic_card,
        **quantities,
        total_available: total_available,
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
