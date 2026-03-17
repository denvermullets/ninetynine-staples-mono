class SyncDeckCombosJob < ApplicationJob
  queue_as :background

  def perform(collection_id)
    collection = Collection.find_by(id: collection_id)
    return unless collection
    return unless Collection.deck_type?(collection.collection_type)

    result = CommanderSpellbook::SyncDeckCombos.call(collection: collection)
    user_id = collection.user_id

    if result[:error]
      broadcast_toast(user_id, result[:error], 'error')
    else
      count = collection.deck_combos.where(combo_type: 'included').count
      msg = count.positive? ? "Found #{count} #{'combo'.pluralize(count)}!" : 'No combos detected'
      broadcast_toast(user_id, msg, 'success')
      broadcast_refresh(user_id)
    end
  end

  private

  def broadcast_toast(user_id, message, type)
    bg_class = type == 'success' ? 'bg-accent-50' : 'bg-accent-100'
    html = <<~HTML
      <div data-controller="toast" class="p-4 rounded-lg shadow-lg text-menu #{bg_class}">
        #{ERB::Util.html_escape(message)}
      </div>
    HTML

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
