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
    broadcast_wants_filled(user_id, result[:wants_filled])
  end

  private

  # wants the precon filled get a toast pointing at the want list, rather than one removal per card
  def broadcast_wants_filled(user_id, items)
    return if items.blank?

    html = ApplicationController.render(
      partial: 'shared/wants_filled_toast',
      locals: { items: items, username: items.first.user.username }
    )

    Turbo::StreamsChannel.broadcast_append_to("user_#{user_id}_notifications", target: 'toasts', html: html)
  end

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
