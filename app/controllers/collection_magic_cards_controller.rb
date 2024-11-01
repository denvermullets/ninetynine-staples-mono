class CollectionMagicCardsController < ApplicationController
  def update_collection
    collection = load_collection_record

    if collection.count.positive?
      collection.first.update(quantity: params[:quantity], foil_quantity: params[:foil_quantity])
    else
      CollectionMagicCard.create!(
        collection_id: collection_params[:collection_id], magic_card_id: collection_params[:magic_card_id],
        quantity: collection_params[:quantity], foil_quantity: collection_params[:foil_quantity]
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
    params.permit(:quantity, :foil_quantity, :collection_id, :magic_card_id)
  end

  def load_collection_record
    # individual collection -> magic_card join
    CollectionMagicCard.where(
      collection_id: collection_params[:collection_id],
      magic_card_id: collection_params[:magic_card_id]
    )
  end
end
