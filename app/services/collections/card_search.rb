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
    def initialize(user:, params:, sort_config:)
      @user = user
      @params = params
      @sort_config = sort_config
    end

    def call
      card_query = CardQuery::Parser.call(query: @params[:search])
      searched = Search::Collection.call(cards: owned_cards, search_term: card_query.free_text,
                                         code: @params[:code], sort_by: :price,
                                         collection_id: @params[:collection_id])
      advanced = CardQuery::Builder.call(cards: sorted(searched), terms: card_query.terms)

      { cards: CollectionQuery::Filter.call(cards: advanced, params: @params), card_query: card_query }
    end

    private

    # scoped to the user up front, and every later stage narrows this relation rather than
    # rebuilding from MagicCard - that rebuild is how the scope got dropped once before
    def owned_cards
      MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: @user.id })
    end

    def sorted(cards)
      CollectionQuery::CollectionSort.call(
        cards: cards, column: @sort_config.column, direction: @sort_config.direction
      )
    end
  end
end
