module DeckBuilderCardActions
  extend ActiveSupport::Concern

  def finalize
    result = DeckBuilder::Finalize.call(deck: @deck)
    result[:success] ? handle_finalize_success(result) : handle_finalize_failure(result)
  end

  def set_commander
    card = @deck.collection_magic_cards.find(params[:card_id])
    return render_error_toast('This card cannot be a commander') unless card.magic_card.can_be_commander
    return render_error_toast('Maximum of 2 commanders allowed') if @deck.commanders.count >= 2

    card.update!(board_type: 'commander')
    render_deck_update_response("#{card.magic_card.name} set as commander")
  end

  def remove_commander
    card = @deck.collection_magic_cards.find(params[:card_id])
    return render_error_toast('This card is not a commander') unless card.commander?

    card.update!(board_type: 'mainboard')
    render_deck_update_response("#{card.magic_card.name} moved to mainboard")
  end

  def transfer_card
    card = @deck.collection_magic_cards.find(params[:card_id])
    to_collection = current_user.collections.find(params[:to_collection_id])
    result = execute_transfer(card, to_collection)

    if result[:success]
      render_deck_update_response("#{card.magic_card.name} transferred to #{to_collection.name}", clear_modal: true)
    else
      render_error_toast(result[:error])
    end
  end

  def swap_printing
    result = DeckBuilder::SwapPrinting.call(
      deck: @deck, collection_magic_card_id: params[:card_id], new_magic_card_id: params[:new_magic_card_id]
    )
    render_card_action_response(result, success_message: "Swapped printing for #{result[:card_name]}")
  end

  def update_staged
    result = DeckBuilder::UpdateStaged.call(deck: @deck, card_id: params[:card_id], quantities: staged_params)
    message = result[:removed] ? "#{result[:card_name]} removed from deck" : "Updated #{result[:card_name]}"
    result[:success] ? render_deck_update_response(message) : render_error_toast(result[:error])
  end

  private

  def staged_params
    { regular: params[:staged_quantity], foil: params[:staged_foil_quantity],
      proxy: params[:staged_proxy_quantity], proxy_foil: params[:staged_proxy_foil_quantity] }
  end

  def execute_transfer(card, to_collection)
    CollectionRecord::Transfer.call(
      params: {
        magic_card_id: card.magic_card_id, from_collection_id: @deck.id, to_collection_id: to_collection.id,
        quantity: card.quantity, foil_quantity: card.foil_quantity,
        proxy_quantity: card.proxy_quantity, proxy_foil_quantity: card.proxy_foil_quantity
      }
    )
  end

  def render_deck_update_response(message, clear_modal: false)
    flash.now[:type] = 'success'
    load_deck_cards
    streams = [
      turbo_stream.update('deck_cards', partial: 'deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_stats'),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
    ]
    streams << turbo_stream.update('deck_modal', '') if clear_modal
    render turbo_stream: streams
  end

  def render_error_toast(message)
    flash.now[:type] = 'error'
    render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
  end

  def handle_finalize_success(result)
    msg = "Deck finalized! #{result[:cards_moved]} cards moved"
    msg += ", #{result[:cards_needed]} cards needed" if result[:cards_needed].positive?
    redirect_to decks_index_path(username: current_user.username), notice: msg, status: :see_other
  end

  def handle_finalize_failure(result)
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_builder/deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_builder/deck_stats'),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: result[:error], type: 'error' })
    ], status: :unprocessable_entity
  end
end
