class MagicCardsController < ApplicationController
  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card: }
  end

  def show_boxset_card
    # TODO: fix if not found
    card = MagicCard.find(params[:id])
    if params[:controller].to_sym == :magic_cards
      collections = current_user&.collections
      editable = current_user ? true : false
    else
      user = User.find_by(username: params[:username])
      collections = user.collections
      editable = user.id == current_user.id
    end

    render partial: 'magic_cards/details', locals: { card:, collections: collections || nil, editable: }
  end
end
