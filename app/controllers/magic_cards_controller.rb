class MagicCardsController < ApplicationController
  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card: }
  end

  def show_boxset_card
    # TODO: fix if not found
    card = MagicCard.find(params[:id])

    # If username param is present, we're viewing someone's collection
    # Otherwise, we're viewing our own cards (or not logged in)
    if params[:username].present?
      user = User.find_by(username: params[:username])
      collections = user&.collections
      editable = current_user && user && user.id == current_user.id
    else
      user = current_user
      collections = current_user&.collections
      editable = current_user ? true : false
    end

    # Fetch all locations where this card exists for the user being viewed
    card_locations = user ? card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id }) : []

    render partial: 'magic_cards/details', locals: { card:, collections: collections || [], card_locations:, editable: }
  end
end
