class CollectionMagicCardsController < ApplicationController
  include WantsFilledToast

  def update_collection
    result = CollectionRecord::CreateOrUpdate.call(params: collection_params)

    if result[:action] == :success
      render_success_toast("Added #{result[:name]} to your collection.")
    else
      render_error_toast("Deleted #{result[:name]} from your collection.")
    end
  end

  def quantity
    collection = load_collection_record

    if collection.any?
      render json: {
        quantity: collection.first.quantity,
        foil_quantity: collection.first.foil_quantity,
        proxy_quantity: collection.first.proxy_quantity,
        proxy_foil_quantity: collection.first.proxy_foil_quantity
      }
    else
      render json: {
        quantity: 0,
        foil_quantity: 0,
        proxy_quantity: 0,
        proxy_foil_quantity: 0
      }
    end
  end

  def transfer
    result = CollectionRecord::Transfer.call(params: transfer_params)

    result[:success] ? render_transfer_success(result) : render_error_toast(result[:error])
  end

  def adjust
    result = CollectionRecord::CreateOrUpdate.call(params: collection_params)

    if %i[success delete].include?(result[:action])
      render_adjust_success(result)
    else
      render_error_toast('Failed to update quantity.')
    end
  end

  # scoped through current_user so an owner can only mark their own copies
  def update_trade
    record = current_user&.collection_magic_cards&.find_by(id: params[:collection_magic_card_id])
    return render_error_toast('Card not found in your collections.') unless record

    result = CollectionRecord::UpdateTrade.call(
      collection_magic_card: record,
      trade_quantity: params[:trade_quantity],
      trade_foil_quantity: params[:trade_foil_quantity]
    )

    result[:success] ? render_trade_success(record, result) : render_error_toast(result[:error])
  end

  private

  def render_transfer_success(result)
    flash.now[:type] = 'success'
    card_id = refresh_card_id(result[:card_id])

    render turbo_stream: [
      turbo_stream.replace(
        "card_details_#{card_id}",
        partial: 'magic_cards/details',
        locals: reload_card_details(card_id)
      ),
      render_success_toast(transfer_message(result))
    ]
  end

  def render_adjust_success(result)
    flash.now[:type] = 'success'
    card_id = refresh_card_id(params[:magic_card_id])

    render turbo_stream: [
      turbo_stream.replace(
        "card_details_#{card_id}",
        partial: 'magic_cards/details',
        locals: reload_card_details(card_id)
      ),
      render_success_toast(adjust_message(result)),
      *wants_filled_toast(result, want_frame_context(card_id))
    ]
  end

  # the params the open card_details frame was loaded with, for the want toast's remove button
  def want_frame_context(card_id)
    { refresh_card_id: card_id, collection_id: params[:row_collection_id],
      show_other_printings: params[:show_other_printings] }.compact_blank
  end

  # refreshes the expanded card details plus the trade pill / Trade column on the collection table row
  def render_trade_success(record, result)
    flash.now[:type] = 'success'
    card_id = record.magic_card_id
    trade_quantity, trade_foil_quantity = row_trade_counts(card_id)
    counts = { card_id:, trade_quantity:, trade_foil_quantity: }

    render turbo_stream: [
      turbo_stream.replace("card_details_#{card_id}", partial: 'magic_cards/details',
                                                      locals: reload_card_details(card_id)),
      turbo_stream.update("trade_pill_#{card_id}", partial: 'collections/trade_pill', locals: counts),
      turbo_stream.update("trade_cell_#{card_id}", partial: 'collections/trade_cell', locals: counts),
      render_success_toast("Updated trade copies of #{result[:name]}.")
    ]
  end

  # the table row sums every collection unless the table was filtered to one, so match that
  def row_trade_counts(card_id)
    records = current_user.collection_magic_cards.where(magic_card_id: card_id)
    records = records.where(collection_id: params[:row_collection_id]) if params[:row_collection_id].present?

    records.pick(Arel.sql('COALESCE(SUM(trade_quantity), 0)'), Arel.sql('COALESCE(SUM(trade_foil_quantity), 0)'))
  end

  # Edits made from the "other printings" table mutate a printing whose expanded row isn't on
  # screen; refresh the row the user actually has open instead.
  def refresh_card_id(mutated_card_id)
    params[:refresh_card_id].presence || mutated_card_id
  end

  def render_success_toast(message)
    turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: })
  end

  def render_error_toast(message)
    flash.now[:type] = 'error'
    render turbo_stream: turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: })
  end

  def transfer_message(result)
    "Transferred #{result[:name]} from #{result[:from_collection]} to #{result[:to_collection]}."
  end

  def adjust_message(result)
    if result[:action] == :delete
      "Removed #{result[:name]} from collection."
    else
      "Updated #{result[:name]} quantity."
    end
  end

  def collection_params
    params.permit(:quantity, :foil_quantity, :proxy_quantity, :proxy_foil_quantity, :collection_id, :magic_card_id,
                  :card_uuid)
  end

  def transfer_params
    params.permit(:magic_card_id, :card_uuid, :from_collection_id, :to_collection_id, :quantity, :foil_quantity,
                  :proxy_quantity, :proxy_foil_quantity)
  end

  def load_collection_record
    records = CollectionMagicCard.where(
      collection_id: collection_params[:collection_id],
      magic_card_id: collection_params[:magic_card_id]
    )
    # records are keyed by printing too, so narrow when the caller knows which one it wants
    card_uuid = collection_params[:card_uuid]
    card_uuid.present? ? records.where(card_uuid: card_uuid) : records
  end

  def reload_card_details(card_id)
    card = MagicCard.find(card_id)
    user = current_user
    collections = user&.collections
    card_locations = user ? card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id }) : []
    editable = user ? true : false
    other_printing_locations = if params[:show_other_printings].present?
                                 card.other_printing_locations(user)
                               else
                                 CollectionMagicCard.none
                               end

    { card:, collections: collections || [], card_locations:, other_printing_locations:, editable:,
      row_collection_id: params[:row_collection_id] }
  end
end
