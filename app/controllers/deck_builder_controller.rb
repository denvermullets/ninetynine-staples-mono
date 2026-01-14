class DeckBuilderController < ApplicationController
  include DeckBuilderModals

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
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update('deck_cards', partial: 'deck_cards'),
          turbo_stream.update('deck_stats', partial: 'deck_stats')
        ]
      end
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
      deck: @deck,
      magic_card_id: params[:magic_card_id],
      source_collection_id: params[:source_collection_id],
      quantity: params[:quantity],
      foil_quantity: params[:foil_quantity]
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
      deck: @deck,
      collection_magic_card_id: params[:card_id],
      quantity: params[:quantity],
      foil_quantity: params[:foil_quantity]
    )
    render_card_action_response(result, success_message: "Updated #{result[:card_name]} quantity")
  end

  def finalize
    result = DeckBuilder::Finalize.call(deck: @deck)
    if result[:success]
      msg = "Deck finalized! #{result[:cards_moved]} cards moved"
      msg += ", #{result[:cards_needed]} cards needed" if result[:cards_needed].positive?
      redirect_to decks_index_path(username: current_user.username), notice: msg, status: :see_other
    else
      flash.now[:error] = result[:error]
      load_deck_cards
      render :show, status: :unprocessable_entity
    end
  end

  private

  def set_deck
    @deck = Collection.find(params[:id])
    @is_owner = current_user&.id == @deck.user_id
  end

  def ensure_owner
    redirect_to root_path, alert: 'Access denied' unless @deck.user_id == current_user.id
  end

  def load_deck_cards
    result = DeckBuilder::LoadCards.call(deck: @deck, grouping: @grouping, sort_by: @sort_by)
    @staged_cards = result[:staged_cards]
    @needed_cards = result[:needed_cards]
    @owned_cards = result[:owned_cards]
    @grouped_cards = result[:grouped_cards]
    @stats = result[:stats]
  end

  def render_card_action_response(result, success_message:)
    return render_error_toast(result[:error]) unless result[:success]

    flash.now[:type] = 'success'
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_stats'),
      turbo_stream.update('header_actions', partial: 'header_actions'),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: success_message })
    ]
  end

  def render_error_toast(message)
    flash.now[:type] = 'error'
    render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
  end
end
