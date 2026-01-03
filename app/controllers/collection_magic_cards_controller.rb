class CollectionMagicCardsController < ApplicationController
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

    if result[:success]
      render_transfer_success(result)
    else
      render_error_toast(result[:error])
    end
  end

  def adjust
    result = CollectionRecord::CreateOrUpdate.call(params: collection_params)

    if %i[success delete].include?(result[:action])
      render_adjust_success(result)
    else
      render_error_toast('Failed to update quantity.')
    end
  end

  private

  def render_transfer_success(result)
    flash.now[:type] = 'success'
    render turbo_stream: [
      turbo_stream.replace(
        "card_details_#{result[:card_id]}",
        partial: 'magic_cards/details',
        locals: result[:locals]
      ),
      render_success_toast(transfer_message(result))
    ]
  end

  def render_adjust_success(result)
    flash.now[:type] = 'success'
    render turbo_stream: [
      turbo_stream.replace(
        "card_details_#{params[:magic_card_id]}",
        partial: 'magic_cards/details',
        locals: reload_card_details(params[:magic_card_id])
      ),
      render_success_toast(adjust_message(result))
    ]
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
    params.permit(:quantity, :foil_quantity, :proxy_quantity, :proxy_foil_quantity, :collection_id, :magic_card_id, :card_uuid)
  end

  def transfer_params
    params.permit(:magic_card_id, :from_collection_id, :to_collection_id, :quantity, :foil_quantity, :proxy_quantity, :proxy_foil_quantity)
  end

  def load_collection_record
    CollectionMagicCard.where(
      collection_id: collection_params[:collection_id],
      magic_card_id: collection_params[:magic_card_id]
    )
  end

  def reload_card_details(card_id)
    card = MagicCard.find(card_id)
    user = current_user
    collections = user&.collections
    card_locations = user ? card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id }) : []
    editable = user ? true : false

    { card:, collections: collections || [], card_locations:, editable: }
  end
end
