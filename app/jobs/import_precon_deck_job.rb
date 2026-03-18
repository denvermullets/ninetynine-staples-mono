class ImportPreconDeckJob < ApplicationJob
  queue_as :collection_updates

  def perform(precon_deck_id, collection_id, user_id)
    precon_deck = PreconDeck.find(precon_deck_id)
    collection = Collection.find(collection_id)

    result = PreconDeckImporter.call(
      precon_deck: precon_deck,
      collection: collection
    )

    broadcast_toast(
      user_id,
      "#{precon_deck.name} imported successfully! (#{result[:cards_imported]} cards)",
      'success'
    )
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
