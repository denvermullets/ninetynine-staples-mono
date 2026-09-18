class MagicCardsController < ApplicationController
  before_action :authenticate_admin!, only: [:destroy]

  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card:, trade_holders: trade_holders(card) }
  end

  def show_boxset_card
    card = MagicCard.find(params[:id])
    user_data = determine_user_and_permissions
    card_locations = fetch_card_locations(card, user_data[:user])
    other_printing_locations = fetch_other_printing_locations(card, user_data[:user])

    render partial: 'magic_cards/details',
           locals: card_details_locals(card, user_data, card_locations, other_printing_locations)
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

  def determine_user_and_permissions
    if params[:username].present?
      user = User.find_by(username: params[:username])
      { user:, collections: user&.ordered_collections, editable: user_owns_collection?(user) }
    else
      { user: current_user, collections: current_user&.ordered_collections, editable: current_user.present? }
    end
  end

  def user_owns_collection?(user)
    current_user && user && user.id == current_user.id
  end

  def fetch_card_locations(card, user)
    return [] unless user

    card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id })
  end

  # The collections and boxsets views ask for this; commander expanded rows opt out.
  def fetch_other_printing_locations(card, user)
    return CollectionMagicCard.none if params[:show_other_printings].blank?

    card.other_printing_locations(user)
  end

  # the back face of a double-faced card renders none of the sections below the card image
  def trade_holders(card)
    return [] unless card.card_side.nil? || card.card_side == 'a'

    MagicCards::TradeHolders.call(card: card, viewer: current_user)
  end

  def card_details_locals(card, user_data, card_locations, other_printing_locations)
    {
      card:,
      collections: user_data[:collections] || [],
      card_locations:,
      other_printing_locations:,
      editable: user_data[:editable],
      trade_holders: trade_holders(card),
      # the collections table filtered to one collection sums trade counts over just that one
      row_collection_id: params[:collection_id]
    }
  end
end
