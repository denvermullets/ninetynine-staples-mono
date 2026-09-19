# Runs a want list bulk add off the request, since a big paste or a big pile of proxies is hundreds of
# inserts. `decklist` is the pasted text for WantList::BulkImport; nil means the proxies button, which
# is WantList::ProxyImport's job.
#
# The report goes out on the user's notification stream as the same two swaps the controller used to
# answer with: the import panel for the report, with the lines to fix left in the textarea, and the
# want_items frame for one that reloads itself from `list_src`. Both are aimed at ids only the want
# list page has, so a user who has wandered off gets just the toast.
class WantImportJob < ApplicationJob
  queue_as :collection_updates

  def perform(user_id, list_src, decklist: nil)
    user = User.find(user_id)
    result = import(user, decklist)

    broadcast_report(user_id, result, retry_text(result, decklist), list_src)
    broadcast_toast(user_id, result)
  end

  private

  def import(user, decklist)
    return WantList::ProxyImport.call(user: user) if decklist.nil?

    WantList::BulkImport.call(user: user, text: decklist)
  end

  # what is left to fix goes back in the textarea; a rejected paste goes back whole
  def retry_text(result, decklist)
    return decklist.to_s unless result[:success]

    (result[:ambiguous] + result[:unresolved]).map { |line| "#{line[:quantity]} #{line[:name]}" }.join("\n")
  end

  def broadcast_report(user_id, result, text, list_src)
    stream = "user_#{user_id}_notifications"

    Turbo::StreamsChannel.broadcast_replace_to(stream, target: 'want_import', partial: 'collection_wants/import',
                                                       locals: { result: result, text: text })
    return unless result[:success]

    Turbo::StreamsChannel.broadcast_replace_to(stream, target: 'want_items',
                                                       partial: 'collection_wants/reload_items',
                                                       locals: { src: list_src })
  end

  def broadcast_toast(user_id, result)
    html = ApplicationController.render(
      partial: 'shared/broadcast_toast',
      locals: { message: toast_message(result), type: result[:success] ? 'success' : 'error' }
    )

    Turbo::StreamsChannel.broadcast_append_to("user_#{user_id}_notifications", target: 'toasts', html: html)
  end

  def toast_message(result)
    return result[:error] unless result[:success]
    return 'Nothing new to add to your want list' if result[:added].empty?

    "Added #{result[:added].size} #{'card'.pluralize(result[:added].size)} to your want list"
  end
end
