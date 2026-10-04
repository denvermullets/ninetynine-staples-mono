class Api::V1::DecksController < Api::V1::BaseController
  # the signed-in user's decks, most recently changed first. ?type=commander narrows to commander decks
  def index
    decks, meta = paginate(deck_scope)
    render json: { data: Api::V1::DeckSummarySerializer.many(decks), meta: meta }
  end

  private

  def deck_scope
    scope = current_api_user.collections.decks.order(updated_at: :desc, id: :desc)
    scope = scope.by_type('commander_deck') if params[:type] == 'commander'
    scope
  end
end
