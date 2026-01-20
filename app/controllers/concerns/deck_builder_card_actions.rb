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

  def swap_printing
    result = DeckBuilder::SwapPrinting.call(
      deck: @deck, collection_magic_card_id: params[:card_id], new_magic_card_id: params[:new_magic_card_id]
    )
    render_card_action_response(result, success_message: "Swapped printing for #{result[:card_name]}")
  end

  def update_staged
    card = @deck.collection_magic_cards.staged.find(params[:card_id])
    new_quantities = {
      regular: params[:staged_quantity].to_i,
      foil: params[:staged_foil_quantity].to_i,
      proxy: params[:staged_proxy_quantity].to_i,
      proxy_foil: params[:staged_proxy_foil_quantity].to_i
    }

    total = new_quantities.values.sum
    if total.zero?
      # Remove the card if all quantities are 0
      card_name = card.magic_card.name
      card.destroy!
      render_deck_update_response("#{card_name} removed from deck")
    else
      result = validate_and_update_staged(card, new_quantities)
      if result[:success]
        render_deck_update_response("Updated #{card.magic_card.name}")
      else
        render_error_toast(result[:error])
      end
    end
  end

  private

  def validate_and_update_staged(card, new_quantities)
    return { success: false, error: 'Quantities cannot be negative' } if new_quantities.values.any?(&:negative?)

    if card.source_collection_id
      source = CollectionMagicCard.find_by(
        collection_id: card.source_collection_id,
        magic_card_id: card.magic_card_id,
        staged: false,
        needed: false
      )

      return { success: false, error: 'Source collection not found' } unless source

      # Calculate available (excluding current card's staged amounts)
      other_staged = CollectionMagicCard.staged
        .where(source_collection_id: card.source_collection_id, magic_card_id: card.magic_card_id)
        .where.not(id: card.id)

      available = {
        regular: source.quantity - other_staged.sum(:staged_quantity),
        foil: source.foil_quantity - other_staged.sum(:staged_foil_quantity),
        proxy: (source.proxy_quantity || 0) - other_staged.sum(:staged_proxy_quantity),
        proxy_foil: (source.proxy_foil_quantity || 0) - other_staged.sum(:staged_proxy_foil_quantity)
      }

      %i[regular foil proxy proxy_foil].each do |type|
        if new_quantities[type] > available[type]
          return { success: false, error: "Only #{available[type]} #{type.to_s.humanize.downcase} available" }
        end
      end
    end

    card.update!(
      staged_quantity: new_quantities[:regular],
      staged_foil_quantity: new_quantities[:foil],
      staged_proxy_quantity: new_quantities[:proxy],
      staged_proxy_foil_quantity: new_quantities[:proxy_foil]
    )
    { success: true }
  end

  def execute_transfer(card, to_collection)
    CollectionRecord::Transfer.call(params: {
                                      magic_card_id: card.magic_card_id,
                                      from_collection_id: @deck.id,
                                      to_collection_id: to_collection.id,
                                      quantity: card.quantity,
                                      foil_quantity: card.foil_quantity,
                                      proxy_quantity: card.proxy_quantity,
                                      proxy_foil_quantity: card.proxy_foil_quantity
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
    load_deck_cards
    render turbo_stream: [
      turbo_stream.update('deck_cards', partial: 'deck_builder/deck_cards'),
      turbo_stream.update('deck_stats', partial: 'deck_builder/deck_stats'),
      turbo_stream.update('deck_modal', ''),
      turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: result[:error], type: 'error' })
    ], status: :unprocessable_entity
  end
end
