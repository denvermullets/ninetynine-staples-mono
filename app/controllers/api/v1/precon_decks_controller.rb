# Preconstructed decks, the client's ready-made opponents. Behind a token like everything else so
# throttling stays per user
class Api::V1::PreconDecksController < Api::V1::BaseController
  # Commander precons, newest release first. ?q= matches part of the name
  def index
    decks, meta = paginate(deck_scope)
    render json: { data: Api::V1::PreconDeckSummarySerializer.many(decks), meta: meta }
  end

  # one Commander precon with its cards and tokens - any other precon is a 404. Answers 304 to a client
  # whose copy is still current
  def show
    deck = PreconDeck.commander_decks.find(params[:id])
    return unless stale?(**deck_cache_validators(deck, deck.precon_deck_cards))

    render json: Api::V1::PreconDeckSerializer.new(deck, rulings: params[:include] == 'rulings')
  end

  private

  def deck_scope
    scope = PreconDeck.commander_decks
    scope = scope.where('precon_decks.name ILIKE ?', "%#{name_query}%") if params[:q].present?
    scope.order(Arel.sql('release_date DESC NULLS LAST'), id: :desc)
  end

  def name_query
    PreconDeck.sanitize_sql_like(params[:q])
  end
end
