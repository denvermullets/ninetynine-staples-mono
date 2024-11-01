class CollectionMagicCardsController < ApplicationController
  def update_collection
    collection = load_collection_record

    if collection.count.positive?
      collection.first.update(
        quantity: collection_params[:quantity] || 0, foil_quantity: collection_params[:foil_quantity] || 0
      )
    else
      CollectionMagicCard.create!(
        collection_id: collection_params[:collection_id], magic_card_id: collection_params[:magic_card_id],
        quantity: collection_params[:quantity] || 0, foil_quantity: collection_params[:foil_quantity] || 0,
        card_uuid: collection_params[:card_uuid]
      )
    end

    :success
  end

  def quantity
    collection = load_collection_record

    if collection.count.positive?
      render json: {
        quantity: collection.first.quantity,
        foil_quantity: collection.first.foil_quantity
      }
    else
      render json: {
        quantity: 0,
        foil_quantity: 0
      }
    end
  end

  private

  def collection_params
    params.permit(:quantity, :foil_quantity, :collection_id, :magic_card_id, :card_uuid)
  end

  def load_collection_record
    CollectionMagicCard.where(
      collection_id: collection_params[:collection_id],
      magic_card_id: collection_params[:magic_card_id]
    )
  end
end
