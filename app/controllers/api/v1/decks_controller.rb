class Api::V1::DecksController < Api::V1::BaseController
  # the signed-in user's decks, most recently changed first. ?type=commander narrows to commander decks
  def index
    decks, meta = paginate(deck_scope)
    render json: { data: Api::V1::DeckSummarySerializer.many(decks), meta: meta }
  end

  # one deck with its cards: the user's own, or anyone's public deck. Someone else's private deck is a
  # 404, same as a deck that doesn't exist. Answers 304 to a client whose copy is still current
  def show
    deck = visible_decks.find(params[:id])
    return unless stale?(**deck_cache_validators(deck, deck.collection_magic_cards))

    render json: Api::V1::DeckSerializer.new(deck, rulings: params[:include] == 'rulings')
  end

  private

  def deck_scope
    scope = current_api_user.collections.decks.order(updated_at: :desc, id: :desc)
    scope = scope.by_type('commander_deck') if params[:type] == 'commander'
    scope
  end

  def visible_decks
    Collection.decks.where(user_id: current_api_user.id).or(Collection.decks.visible_to_public)
  end
end
