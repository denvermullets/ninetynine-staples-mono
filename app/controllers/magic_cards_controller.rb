class MagicCardsController < ApplicationController
  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card: }
  end

  def show_boxset_card
    card = MagicCard.find(params[:id])
    collections = current_user.collections

    render partial: 'magic_cards/details', locals: { card:, collections: }
  end
end
