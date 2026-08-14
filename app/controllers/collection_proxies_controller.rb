# The proxies one collection holds, and whether the real card is already somewhere in the binder.
#
# Not authenticated, same as the stats dashboard and the set page: Scope decides which of the named
# user's collections the viewer is allowed to see, and a public one is readable logged out.
# current_user is who is looking, never whose cards are being counted.
#
# The list lives in a turbo frame with turbo_action advance, so the filter links and the pagination
# inside it swap the table and move the URL without a stimulus controller or a turbo_stream endpoint
# of their own.
class CollectionProxiesController < ApplicationController
  PER_PAGE = 50

  def show
    @scope = CollectionStats::Scope.call(username: params[:username], viewer: current_user,
                                         collection_id: params[:collection_id])
    return bounce_to_whole_collection if @scope[:missing]

    @filter = requested_filter
    @location = requested_location
    load_proxies unless @scope[:collection_ids].empty?
  end

  private

  # Dropping the collection_id rather than keeping it, or the redirect would loop
  def bounce_to_whole_collection
    redirect_to collection_proxies_path(params[:username]), alert: 'Collection not found'
  end

  def requested_filter
    return params[:filter] if CollectionStats::ProxyCards::FILTERS.include?(params[:filter])

    'all'
  end

  def requested_location
    return params[:location] if CollectionStats::ProxyCards::LOCATIONS.include?(params[:location])

    'all'
  end

  # THE TWO ID LISTS ARE DIFFERENT AND THAT IS THE POINT. collection_ids is what the picker narrowed
  # to and decides which proxies are listed; the search list is every collection the viewer can see
  # and decides where a real copy counts as found. Passing collection_ids for both is the one mistake
  # here that looks like it works - the page would keep rendering, and every proxy in the selected
  # collection would read "proxy only" however many real copies sat in the binder next to it.
  def load_proxies
    proxies = CollectionStats::ProxyCards.call(
      proxy_collection_ids: @scope[:collection_ids],
      search_collection_ids: @scope[:collections].map(&:id),
      filter: @filter, location: @location
    )

    @counts = proxies[:counts]
    @location_counts = proxies[:location_counts]
    @totals = proxies[:totals]
    @pagy, @rows = pagy(:offset, proxies[:rows], limit: PER_PAGE)
    @labels = CollectionStats::PrintingLabels.call(magic_card_ids: page_printing_ids)
  end

  # After pagy, so labels are looked up for the printings actually on screen rather than for every
  # proxy in the collection. The real locations are in here too, not just the rows: the expansion's
  # whole job is telling you WHICH version you already own, and "3ED #286 showcase" does that where
  # a bare number does not.
  def page_printing_ids
    @rows.flat_map { |row| [row[:id], *row[:real_locations].map { |location| location[:printing_id] }] }
  end
end
