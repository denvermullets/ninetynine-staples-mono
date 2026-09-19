# Bulk add on the want list page: a pasted decklist becomes any-printing wants for the signed-in user.
# WantList::BulkImport does the parsing and name resolution. The panel's other button skips the paste
# and adds the proxies they are holding, which is WantList::ProxyImport's job.
#
# Answered with turbo streams rather than a redirect, because the report of what could not be matched
# can run to dozens of names - more than a cookie flash holds. The import panel is swapped for the
# report, with the lines to fix left in the textarea, and the want_items frame is swapped for one that
# reloads itself from the page, so the list and its pill counts pick up the new rows.
class WantImportsController < ApplicationController
  before_action :authenticate_user!

  def create
    result = WantList::BulkImport.call(user: current_user, text: params[:decklist])

    render_report(result, retry_text(result))
  end

  def proxies
    render_report(WantList::ProxyImport.call(user: current_user), '')
  end

  private

  def render_report(result, text)
    render turbo_stream: [
      turbo_stream.replace('want_import', partial: 'collection_wants/import',
                                          locals: { result: result, text: text }),
      turbo_stream.replace('want_items', partial: 'collection_wants/reload_items',
                                         locals: { src: list_src })
    ]
  end

  # what is left to fix goes back in the textarea; a rejected paste goes back whole
  def retry_text(result)
    return params[:decklist] unless result[:success]

    (result[:ambiguous] + result[:unresolved]).map { |line| "#{line[:quantity]} #{line[:name]}" }.join("\n")
  end

  # the filter and sort the page was on, read back off the page's URL; the page resets, since the
  # rows under it just moved
  def list_src
    path = collection_wants_path(current_user.username)
    referer = URI.parse(request.referer.to_s)
    return path unless referer.path == path

    view = Rack::Utils.parse_query(referer.query).slice('filter', 'sort').compact_blank
    collection_wants_path(current_user.username, **view.symbolize_keys)
  rescue URI::InvalidURIError
    path
  end
end
