module DeckBuilder
  class Search < Service
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
      results = []

      owned_results = build_owned_results
      results.concat(owned_results)

      if results.size < @limit
        latest_results = build_latest_results(owned_results)
        results.concat(latest_results.first(@limit - results.size))
      end

      results.first(@limit)
    end

    def search_owned_only
      build_owned_results.first(@limit)
    end

    def build_owned_results
      owned_cards = CollectionMagicCard
        .joins(:collection, :magic_card)
        .includes(magic_card: :boxset, collection: [])
        .where(collections: { user_id: @user.id })
        .where(staged: false, needed: false)
        .where('magic_cards.name ILIKE ?', "%#{@query}%")
        .order('magic_cards.name ASC')

      owned_cards.filter_map do |cmc|
        quantities = calculate_available_quantities(cmc)
        next if quantities[:total_available].zero? && quantities[:total_foil_available].zero?

        already_in_deck = @deck.collection_magic_cards.exists?(
          magic_card_id: cmc.magic_card_id,
          source_collection_id: cmc.collection_id
        )

        {
          type: :owned,
          card: cmc.magic_card,
          collection_magic_card_id: cmc.id,
          collection_id: cmc.collection_id,
          collection_name: cmc.collection.name,
          quantities: quantities,
          already_in_deck: already_in_deck
        }
      end
    end

    def build_latest_results(_owned_results)
      newest_card_ids = MagicCard
        .joins(:boxset)
        .select('DISTINCT ON (magic_cards.name) magic_cards.id')
        .where('magic_cards.name ILIKE ?', "%#{@query}%")
        .order('magic_cards.name, boxsets.release_date DESC')

      MagicCard
        .where(id: newest_card_ids)
        .includes(:boxset)
        .order(:name)
        .map do |card|
          already_in_deck = @deck.collection_magic_cards.exists?(magic_card_id: card.id)

          {
            type: :latest,
            card: card,
            already_in_deck: already_in_deck
          }
        end
    end

    def calculate_available_quantities(cmc)
      staged_regular = reserved_quantity(cmc, :staged_quantity)
      staged_foil = reserved_quantity(cmc, :staged_foil_quantity)

      available_regular = cmc.quantity - staged_regular
      available_foil = cmc.foil_quantity - staged_foil
      proxy_qty = cmc.proxy_quantity || 0
      proxy_foil_qty = cmc.proxy_foil_quantity || 0

      {
        regular: available_regular,
        foil: available_foil,
        proxy: proxy_qty,
        proxy_foil: proxy_foil_qty,
        total_available: available_regular + proxy_qty,
        total_foil_available: available_foil + proxy_foil_qty
      }
    end

    def reserved_quantity(cmc, type)
      CollectionMagicCard
        .staged
        .where(source_collection_id: cmc.collection_id, magic_card_id: cmc.magic_card_id)
        .sum(type)
    end
  end
end
