class MagicCardsController < ApplicationController
  def show
    card = MagicCard.find(params[:id])

    render partial: 'magic_cards/details', locals: { card: }
  end

  def show_boxset_card
    card = MagicCard.find(params[:id])
    user_data = determine_user_and_permissions
    card_locations = fetch_card_locations(card, user_data[:user])

    render partial: 'magic_cards/details', locals: card_details_locals(card, user_data, card_locations)
  end

  private

  def determine_user_and_permissions
    if params[:username].present?
      user = User.find_by(username: params[:username])
      { user:, collections: user&.collections, editable: user_owns_collection?(user) }
    else
      { user: current_user, collections: current_user&.collections, editable: current_user.present? }
    end
  end

  def user_owns_collection?(user)
    current_user && user && user.id == current_user.id
  end

  def fetch_card_locations(card, user)
    return [] unless user

    card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id })
  end

  def card_details_locals(card, user_data, card_locations)
    {
      card:,
      collections: user_data[:collections] || [],
      card_locations:,
      editable: user_data[:editable]
    }
  end
end
