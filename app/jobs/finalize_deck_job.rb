class FinalizeDeckJob < ApplicationJob
  queue_as :collection_updates

  def perform(deck_id, user_id)
    deck = Collection.find(deck_id)
    result = DeckBuilder::Finalize.call(deck: deck)

    if result[:success]
      msg = "Deck finalized! #{result[:cards_moved]} cards moved"
      msg += ", #{result[:cards_needed]} cards needed" if result[:cards_needed].positive?
      broadcast_toast(user_id, msg, 'success')
      broadcast_refresh(user_id)
    else
      broadcast_toast(user_id, result[:error], 'error')
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
