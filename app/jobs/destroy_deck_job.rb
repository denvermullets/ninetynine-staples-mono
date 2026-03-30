class DestroyDeckJob < ApplicationJob
  queue_as :collection_updates

  def perform(deck_id, user_id)
    deck = Collection.find_by(id: deck_id)
    return unless deck

    deck_name = deck.name
    CollectionMagicCard.where(source_collection_id: deck.id).update_all(source_collection_id: nil)
    CollectionMagicCard.where(collection_id: deck.id).delete_all
    deck.destroy!

    Turbo::StreamsChannel.broadcast_remove_to(
      "user_#{user_id}_notifications",
      target: "collection_card_#{deck_id}"
    )

    broadcast_toast(user_id, "\"#{deck_name}\" has been deleted", 'success')
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
