class SyncDeckCombosJob < ApplicationJob
  queue_as :background

  # Opening the Suggestions panel queues a check whenever the deck is stale, so reopening it before the
  # first check lands must not stack a second Spellbook call for the same deck.
  limits_concurrency key: ->(collection_id, *) { collection_id }, on_conflict: :discard

  # notify: false is the panel's background check - nobody pressed a button, so no toast, but the page
  # refresh still reloads the suggestions frame with the new combo pieces.
  def perform(collection_id, notify: true)
    collection = Collection.find_by(id: collection_id)
    return unless collection
    return unless Collection.deck_type?(collection.collection_type)

    result = CommanderSpellbook::SyncDeckCombos.call(collection: collection)
    user_id = collection.user_id

    if result[:error]
      broadcast_toast(user_id, result[:error], 'error') if notify
    else
      broadcast_toast(user_id, found_message(collection), 'success') if notify
      broadcast_refresh(user_id)
    end
  end

  private

  def found_message(collection)
    count = collection.deck_combos.where(combo_type: 'included').count
    count.positive? ? "Found #{count} #{'combo'.pluralize(count)}!" : 'No combos detected'
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

  def broadcast_refresh(user_id)
    Turbo::StreamsChannel.broadcast_refresh_to("user_#{user_id}_notifications")
  end
end
