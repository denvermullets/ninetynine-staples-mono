module DeckBuilderCardActions
  extend ActiveSupport::Concern

  def finalize
    unless @deck.in_build_mode?
      render_error_toast('No staged cards to finalize')
      return
    end

    FinalizeDeckJob.perform_later(@deck.id, current_user.id)

    flash.now[:type] = 'success'
    message = "#{@deck.name} is being finalized. Cards will be moved shortly."
    render turbo_stream: [
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
    ]
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
      invalidate_combos_for(card.magic_card.scryfall_oracle_id)
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

  def change_card_type
    result = DeckBuilder::ChangeCardType.call(deck: @deck, card_id: params[:card_id], card_type: params[:card_type])
    message = "#{result[:card_name]} changed to #{result[:card_type]&.tr('_', ' ')}"
    render_card_action_response(result, success_message: message)
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
end
