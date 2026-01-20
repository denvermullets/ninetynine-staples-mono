# rubocop:disable Metrics/ClassLength
class DeckBuilderController < ApplicationController
  include DeckBuilderModals
  include DeckBuilderCardActions

  before_action :set_deck
  before_action :authenticate_user!, except: [:show]
  before_action :ensure_owner, except: [:show]

  def show
    @view_mode = params[:view_mode] || 'list'
    @grouping = params[:grouping] || 'type'
    @sort_by = params[:sort_by] || 'mana_value'
    @search_scope = params[:search_scope] || 'all'
    load_deck_cards
    respond_to do |format|
      format.html
      format.turbo_stream { render_deck_cards_stream }
    end
  end

  def search
    @results = DeckBuilder::Search.call(
      query: params[:q], user: current_user, deck: @deck, scope: params[:scope] || 'all', limit: 20
    )
    render partial: 'search_results', locals: { results: @results }
  end

  def add_card
    result = DeckBuilder::AddCard.call(
      deck: @deck, magic_card_id: params[:magic_card_id], source_collection_id: params[:source_collection_id],
      card_type: params[:card_type] || 'regular', quantity: params[:quantity]
    )
    render_card_action_response(result, success_message: "Added #{result[:card_name]}")
  end

  def remove_card
    result = DeckBuilder::RemoveCard.call(deck: @deck, collection_magic_card_id: params[:card_id])
    render_card_action_response(result, success_message: result[:message])
  end

  def swap_card
    result = DeckBuilder::SwapCard.call(
      deck: @deck, collection_magic_card_id: params[:card_id], source_collection_id: params[:source_collection_id]
    )
    render_card_action_response(result, success_message: "Swapped #{result[:card_name]}")
  end

  def update_quantity
    result = DeckBuilder::UpdateQuantity.call(
      deck: @deck, collection_magic_card_id: params[:card_id],
      quantity: params[:quantity], foil_quantity: params[:foil_quantity]
    )
    render_card_action_response(result, success_message: "Updated #{result[:card_name]} quantity")
  end

  def add_new_card
    result = DeckBuilder::AddNewCard.call(
      deck: @deck, magic_card_id: params[:magic_card_id], card_type: params[:card_type], quantity: params[:quantity]
    )
    render_card_action_response(result, success_message: "Added #{result[:card_name]}")
  end

  def update_deck
    @deck.update(deck_params) ? render_update_deck_success : render_error_toast('Failed to update deck')
  end

  def swap_source
    result = DeckBuilder::SwapSource.call(
      deck: @deck, collection_magic_card_id: params[:card_id],
      new_source_collection_id: params[:source_collection_id], new_magic_card_id: params[:magic_card_id]
    )
    render_card_action_response(result, success_message: "Changed source to #{result[:source_name]}")
  end

  private

  def set_deck
    @deck = Collection.find(params[:id])
    @is_owner = current_user&.id == @deck.user_id
  end

  def ensure_owner
    redirect_to(root_path, alert: 'Access denied') unless @deck.user_id == current_user.id
  end

  def load_deck_cards
    result = DeckBuilder::LoadCards.call(deck: @deck, grouping: @grouping, sort_by: @sort_by)
    @staged_cards, @needed_cards, @owned_cards = result.values_at(:staged_cards, :needed_cards, :owned_cards)
    @grouped_cards, @stats = result.values_at(:grouped_cards, :stats)
  end

  def render_card_action_response(result, success_message:)
    return render_error_toast(result[:error]) unless result[:success]

    flash.now[:type] = 'success'
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_stats'),
      turbo_stream.update('header_actions', partial: 'header_actions'),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: success_message })
    ]
  end

  def render_deck_cards_stream
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_stats')
    ]
  end

  def render_update_deck_success
    flash.now[:type] = 'success'
    render turbo_stream: [
      turbo_stream.update('deck-name', @deck.name),
      turbo_stream.update('deck-description', @deck.description),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: 'Deck updated successfully' })
    ]
  end

  def deck_params = params.permit(:name, :description, :collection_type)
end
# rubocop:enable Metrics/ClassLength
