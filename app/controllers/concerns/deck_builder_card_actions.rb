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
      render_transfer_success(card.magic_card.name, to_collection.name)
    else
      render_error_toast(result[:error])
    end
  end

  private

  def execute_transfer(card, to_collection)
    CollectionRecord::Transfer.call(params: {
                                      magic_card_id: card.magic_card_id,
                                      from_collection_id: @deck.id,
                                      to_collection_id: to_collection.id,
                                      quantity: card.quantity,
                                      foil_quantity: card.foil_quantity,
                                      proxy_quantity: 0,
                                      proxy_foil_quantity: 0
                                    })
  end

  def render_transfer_success(card_name, collection_name)
    flash.now[:type] = 'success'
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_stats'),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast',
                                    locals: { message: "#{card_name} transferred to #{collection_name}" })
    ]
  end

  def render_deck_update_response(message)
    flash.now[:type] = 'success'
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_stats'),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
    ]
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
    flash.now[:error] = result[:error]
    load_deck_cards
    render :show, status: :unprocessable_entity
  end
end
