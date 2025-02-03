class MagicCardsController < ApplicationController
  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card: }
  end

  def show_boxset_card
    # TODO: fix if not found
    card = MagicCard.find(params[:id])
    user = User.find_by(username: params[:username])
    collections = user.collections
    editable = user.id == current_user.id

    render partial: 'magic_cards/details', locals: { card:, collections: collections || nil, editable: }
  end
end
