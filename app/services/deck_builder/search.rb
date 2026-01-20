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

      results = []

      owned_cards.each do |cmc|
        quantities = calculate_available_quantities(cmc)

        already_in_deck = @deck.collection_magic_cards.exists?(
          magic_card_id: cmc.magic_card_id,
          source_collection_id: cmc.collection_id
        )

        base_result = {
          type: :owned,
          card: cmc.magic_card,
          collection_magic_card_id: cmc.id,
          collection_id: cmc.collection_id,
          collection_name: cmc.collection.name,
          already_in_deck: already_in_deck
        }

        # Create separate results for each available card type
        if quantities[:regular] > 0
          results << base_result.merge(
            card_type: :regular,
            available: quantities[:regular],
            type_label: 'Regular'
          )
        end

        if quantities[:foil] > 0
          results << base_result.merge(
            card_type: :foil,
            available: quantities[:foil],
            type_label: 'Foil'
          )
        end

        if quantities[:proxy] > 0
          results << base_result.merge(
            card_type: :proxy,
            available: quantities[:proxy],
            type_label: 'Proxy'
          )
        end

        if quantities[:proxy_foil] > 0
          results << base_result.merge(
            card_type: :proxy_foil,
            available: quantities[:proxy_foil],
            type_label: 'Foil Proxy'
          )
        end
      end

      results
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
      staged_proxy = reserved_quantity(cmc, :staged_proxy_quantity)
      staged_proxy_foil = reserved_quantity(cmc, :staged_proxy_foil_quantity)

      available_regular = cmc.quantity - staged_regular
      available_foil = cmc.foil_quantity - staged_foil
      available_proxy = (cmc.proxy_quantity || 0) - staged_proxy
      available_proxy_foil = (cmc.proxy_foil_quantity || 0) - staged_proxy_foil

      {
        regular: [available_regular, 0].max,
        foil: [available_foil, 0].max,
        proxy: [available_proxy, 0].max,
        proxy_foil: [available_proxy_foil, 0].max
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
