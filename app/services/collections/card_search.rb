#
# the collections search pipeline, in the one order that works
#
# The search box doubles as a Scryfall-style query box: CardQuery::Parser pulls out any recognized
# terms and leaves the rest as the name search, so a query with no terms behaves as before.
#
# Search::Collection has to run first - it's what groups by magic_cards.id and selects the quantity
# aggregates. Builder and Filter both emit HAVING clauses over those aggregates and silently no-op
# on an ungrouped relation, so reordering these stages loses filters without failing.
#
module Collections
  class CardSearch < Service
    # tradeable narrows the base to copies marked for trade in public collections before anything
    # else runs, so the aggregates the later stages read are trade-list totals, not whole-shelf ones
    def initialize(user:, params:, sort_config:, current_user: nil, tradeable: false)
      @user = user
      @current_user = current_user
      @params = params
      @sort_config = sort_config
      @tradeable = tradeable
    end

    def call
      card_query = CardQuery::Parser.call(query: @params[:search])
      searched = Search::Collection.call(cards: owned_cards, search_term: card_query.free_text,
                                         code: @params[:code], sort_by: :price,
                                         collection_id: @params[:collection_id])
      advanced = CardQuery::Builder.call(cards: sorted(searched), terms: card_query.terms, viewer_id: viewer_id)

      { cards: CollectionQuery::Filter.call(cards: advanced, params: @params), card_query: card_query }
    end

    private

    # This page also renders other people's public collections, so otag: may only see the searcher's own
    # tags when they are the one who owns what is being searched.
    def viewer_id
      @user.id if @current_user&.id == @user.id
    end

    # scoped to the user up front, and every later stage narrows this relation rather than
    # rebuilding from MagicCard - that rebuild is how the scope got dropped once before
    def owned_cards
      cards = MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: @user.id })
      return cards unless @tradeable

      cards.merge(CollectionMagicCard.tradeable).merge(Collection.visible_to_public)
    end

    def sorted(cards)
      CollectionQuery::CollectionSort.call(
        cards: cards, column: @sort_config.column, direction: @sort_config.direction
      )
    end
  end
end
