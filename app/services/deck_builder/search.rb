module DeckBuilder
  class Search < Service
    CARD_TYPES = %i[regular foil proxy proxy_foil].freeze
    TYPE_LABELS = { regular: 'Regular', foil: 'Foil', proxy: 'Proxy', proxy_foil: 'Foil Proxy' }.freeze

    def initialize(query:, user:, deck:, scope: 'all', limit: 20)
      @query = query
      @user = user
      @deck = deck
      @scope = scope
      @limit = limit
    end

    def call
      return [] if @query.blank? || @query.length < 2

      @scope == 'owned' ? search_owned_only : search_all_cards
    end

    private

    def search_all_cards
      results = build_owned_results

      if results.size < @limit
        latest_results = build_latest_results
        results.concat(latest_results.first(@limit - results.size))
      end

      results.first(@limit)
    end

    def search_owned_only
      build_owned_results.first(@limit)
    end

    def build_owned_results
      owned_cards.flat_map { |cmc| results_for_card(cmc) }
    end

    def owned_cards
      CollectionMagicCard
        .joins(:collection, :magic_card)
        .includes(magic_card: :boxset, collection: [])
        .where(collections: { user_id: @user.id })
        .where(staged: false, needed: false)
        .where(magic_cards: { is_token: false })
        .where('magic_cards.name ILIKE ?', "%#{@query}%")
        .order('magic_cards.name ASC')
    end

    def results_for_card(cmc)
      quantities = calculate_available_quantities(cmc)
      base = build_base_result(cmc)

      CARD_TYPES.filter_map do |type|
        next unless quantities[type].positive?

        base.merge(card_type: type, available: quantities[type], type_label: TYPE_LABELS[type])
      end
    end

    def build_base_result(cmc)
      {
        type: :owned,
        card: cmc.magic_card,
        collection_magic_card_id: cmc.id,
        collection_id: cmc.collection_id,
        collection_name: cmc.collection.name,
        already_in_deck: already_in_deck?(cmc)
      }
    end

    def already_in_deck?(cmc)
      @deck.collection_magic_cards.exists?(
        magic_card_id: cmc.magic_card_id,
        source_collection_id: cmc.collection_id
      )
    end

    def build_latest_results
      MagicCard
        .where(id: newest_card_ids)
        .includes(:boxset)
        .order(:name)
        .map { |card| build_latest_result(card) }
    end

    def newest_card_ids
      MagicCard
        .joins(:boxset)
        .select('DISTINCT ON (magic_cards.name) magic_cards.id')
        .where(is_token: false)
        .where('magic_cards.name ILIKE ?', "%#{@query}%")
        .order('magic_cards.name, boxsets.release_date DESC')
    end

    def build_latest_result(card)
      {
        type: :latest,
        card: card,
        already_in_deck: @deck.collection_magic_cards.exists?(magic_card_id: card.id)
      }
    end

    def calculate_available_quantities(cmc)
      staged = StagedQuantities.call(
        source_collection_id: cmc.collection_id,
        magic_card_id: cmc.magic_card_id
      )

      {
        regular: [cmc.quantity - staged[:regular], 0].max,
        foil: [cmc.foil_quantity - staged[:foil], 0].max,
        proxy: [(cmc.proxy_quantity || 0) - staged[:proxy], 0].max,
        proxy_foil: [(cmc.proxy_foil_quantity || 0) - staged[:proxy_foil], 0].max
      }
    end
  end
end
