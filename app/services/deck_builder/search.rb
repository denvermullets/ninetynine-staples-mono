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

      cards = @scope == 'owned' ? search_owned_cards : search_all_cards
      cards.map { |card| build_search_result(card) }
    end

    private

    def search_all_cards
      # Get IDs of newest version of each card (by release_date)
      newest_card_ids = MagicCard
                        .joins(:boxset)
                        .select('DISTINCT ON (magic_cards.name) magic_cards.id')
                        .where('magic_cards.name ILIKE ?', "%#{@query}%")
                        .order('magic_cards.name, boxsets.release_date DESC')

      MagicCard
        .where(id: newest_card_ids)
        .includes(:boxset)
        .order(:name)
        .limit(@limit)
    end

    def search_owned_cards
      # Get IDs of newest version of each owned card (by release_date)
      newest_card_ids = MagicCard
                        .joins(:boxset, collection_magic_cards: :collection)
                        .select('DISTINCT ON (magic_cards.name) magic_cards.id')
                        .where(collections: { user_id: @user.id })
                        .where(collection_magic_cards: { staged: false, needed: false })
                        .where('magic_cards.name ILIKE ?', "%#{@query}%")
                        .order('magic_cards.name, boxsets.release_date DESC')

      MagicCard
        .where(id: newest_card_ids)
        .includes(:boxset)
        .order(:name)
        .limit(@limit)
    end

    def build_search_result(card)
      owned_copies = card.collection_magic_cards
                         .joins(:collection)
                         .where(collections: { user_id: @user.id })
                         .where(staged: false, needed: false)
                         .includes(:collection)

      already_in_deck = @deck.collection_magic_cards.exists?(magic_card_id: card.id)

      {
        card: card,
        owned_copies: owned_copies.map { |cmc| format_owned_copy(cmc) },
        already_in_deck: already_in_deck
      }
    end

    def format_owned_copy(cmc)
      {
        collection_id: cmc.collection_id,
        collection_name: cmc.collection.name,
        quantity: cmc.quantity,
        foil_quantity: cmc.foil_quantity,
        proxy_quantity: cmc.proxy_quantity || 0,
        proxy_foil_quantity: cmc.proxy_foil_quantity || 0,
        available_quantity: cmc.quantity - reserved_quantity(cmc, :staged_quantity),
        available_foil_quantity: cmc.foil_quantity - reserved_quantity(cmc, :staged_foil_quantity)
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
