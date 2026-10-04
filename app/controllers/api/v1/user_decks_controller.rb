# Another player's public decks, so the client can battle a friend's deck. The detail comes from
# GET /api/v1/decks/:id, which already serves public decks
class Api::V1::UserDecksController < Api::V1::BaseController
  # public decks only, most recently changed first, in the same shape as GET /api/v1/decks. An unknown
  # username is a 404
  def index
    decks, meta = paginate(deck_scope)
    render json: { data: Api::V1::DeckSummarySerializer.many(decks), meta: meta }
  end

  private

  def deck_scope
    user.collections.decks.visible_to_public.order(updated_at: :desc, id: :desc)
  end

  # case-insensitive, matching the lower(username) unique index
  def user
    User.where('lower(username) = ?', params[:username].downcase).first!
  end
end
