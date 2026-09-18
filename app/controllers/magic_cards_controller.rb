class MagicCardsController < ApplicationController
  include CardDetailsLocals

  before_action :authenticate_admin!, only: [:destroy]

  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card:, trade_holders: trade_holders(card) }
  end

  def show_boxset_card
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: card_details_locals(card)
  end

  def destroy
    card = MagicCard.find(params[:id])

    if card.collection_magic_cards.exists?
      flash.now[:type] = 'error'
      render turbo_stream: turbo_stream.append(
        'toasts', partial: 'shared/toast',
                  locals: {
                    message: "Cannot delete #{card.name} - it exists in one or more collections"
                  }
      )
    else
      card_name = card.name
      card.destroy!
      render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast',
                                                         locals: { message: "Successfully deleted #{card_name}" })
    end
  end

  private

  def authenticate_admin!
    return if current_user&.role.to_i == 9001

    render plain: 'Unauthorized', status: :unauthorized
  end
end
