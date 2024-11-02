class MagicCardsController < ApplicationController
  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card: }
  end

  def show_boxset_card
    card = MagicCard.find(params[:id])
    collections = current_user.collections if current_user

    render partial: 'magic_cards/details', locals: { card:, collections: collections || nil }
  end
end
