class DestroyCollectionJob < ApplicationJob
  queue_as :collection_updates

  # Collection totals and value history are summed from the remaining collections on every read,
  # so removing the rows is all it takes for the user's overall numbers to drop.
  def perform(collection_id, user_id)
    collection = Collection.find_by(id: collection_id)
    return unless collection

    collection_name = collection.name
    card_ids = CollectionMagicCard.where(collection_id: collection.id).select(:id)

    Collection.transaction do
      CollectionMagicCard.where(source_collection_id: collection.id).update_all(source_collection_id: nil)
      # delete_all skips CollectionMagicCard's dependent: :nullify, and trade_items has a foreign key
      TradeItem.where(collection_magic_card_id: card_ids).update_all(collection_magic_card_id: nil)
      CollectionMagicCard.where(collection_id: collection.id).delete_all
      collection.destroy!
    end

    Turbo::StreamsChannel.broadcast_remove_to(
      "user_#{user_id}_notifications",
      target: "collection_card_#{collection_id}"
    )

    broadcast_toast(user_id, "\"#{collection_name}\" has been deleted", 'success')
  end

  private

  def broadcast_toast(user_id, message, type)
    html = ApplicationController.render(
      partial: 'shared/broadcast_toast',
      locals: { message: message, type: type }
    )

    Turbo::StreamsChannel.broadcast_append_to(
      "user_#{user_id}_notifications",
      target: 'toasts',
      html: html
    )
  end
end
