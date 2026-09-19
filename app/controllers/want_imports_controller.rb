# Bulk add on the want list page: a pasted decklist becomes any-printing wants for the signed-in user.
# WantList::BulkImport does the parsing and name resolution. The panel's other button skips the paste
# and adds the proxies they are holding, which is WantList::ProxyImport's job.
#
# The adding is WantImportJob's: a big paste is hundreds of inserts, too long to hold a request for. The
# answer here is a turbo stream that swaps the import panel for one that says the import is running;
# the job broadcasts the report into the same panel, and reloads the want_items frame, when it is done.
class WantImportsController < ApplicationController
  before_action :authenticate_user!

  def create
    WantImportJob.perform_later(current_user.id, list_src, decklist: params[:decklist].to_s)

    render_pending(params[:decklist].to_s)
  end

  def proxies
    WantImportJob.perform_later(current_user.id, list_src)

    render_pending('')
  end

  private

  # the paste stays in the textarea until the report replaces it, so nothing is lost if the job dies
  def render_pending(text)
    render turbo_stream: turbo_stream.replace('want_import', partial: 'collection_wants/import',
                                                             locals: { result: nil, text: text, pending: true })
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
