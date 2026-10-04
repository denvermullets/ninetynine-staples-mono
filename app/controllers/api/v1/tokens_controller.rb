# Token definitions for the client's "create token" tool. Sets reprint the same token over and over, so
# printings that would play the same - same name, power/toughness, colors and text - come back once,
# as their canonical printing
class Api::V1::TokensController < Api::V1::BaseController
  # full card objects, by name. ?q= matches part of the name, ignoring case
  def index
    tokens, meta = paginate(token_scope)
    render json: { data: Api::V1::CardSerializer.many(tokens, rulings: params[:include] == 'rulings'), meta: meta }
  end

  private

  # front faces only - the serializer nests the back of a double-faced token under its front
  def token_scope
    scope = MagicCard.where(is_token: true, card_side: [nil, 'a'])
    scope = scope.where(*MagicCard.name_containing(params[:q])) if params[:q].present?
    scope.canonical_printings(by: :same_token).order(:name, :id)
  end
end
