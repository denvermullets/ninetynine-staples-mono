# Every card that moved, the full-page version of the stats dashboard's Weekly Price Movers panel.
#
# Not authenticated, same as the stats dashboard it expands: Scope decides which of the named user's
# collections the viewer is allowed to see, and a public one is readable logged out. current_user is
# who is looking, never whose cards are being counted. @scope[:owner] is what decides whether the
# alert controls render, and only then is the viewer's own movement rule for these filters looked up.
#
# CollectionStats::MoversTable whitelists every filter and does its own paging, so this only passes
# the params through and wraps its total for Pagy. The filters and the table share one turbo frame
# with turbo_action advance, so every filter, sort and page is a URL you can bookmark.
class CollectionMoversController < ApplicationController
  FILTER_PARAMS = %i[window direction finish min_delta min_percent min_price min_buylist max_buylist
                     sort dir].freeze

  def show
    @scope = CollectionStats::Scope.call(username: params[:username], viewer: current_user,
                                         collection_id: params[:collection_id])
    return bounce_to_whole_collection if @scope[:missing]
    return if @scope[:collection_ids].empty?

    load_moves
    # the total counts every page, so an empty page past the end is a stale link - start it over
    redirect_to first_page if @rows.empty? && @pagy.page > 1
  end

  private

  # Dropping the collection_id rather than keeping it, or the redirect would loop
  def bounce_to_whole_collection
    redirect_to collection_movers_path(params[:username]), alert: 'Collection not found'
  end

  def load_moves
    result = CollectionStats::MoversTable.call(collection_ids: @scope[:collection_ids],
                                               filters: filter_params, page: params[:page])

    @filters = result[:filters]
    @rows = result[:rows]
    @total = result[:total]
    @pagy = Pagy::Offset.new(count: @total, page: result[:page], limit: result[:per_page], request: request)
    load_alert_rule if @scope[:owner]
  end

  # the movement rule these filters would save as, and the active one already counting them, if any
  def load_alert_rule
    @rule_attributes = PriceAlert.movement_rule_attributes(@filters, collection_id: @scope[:collection]&.id)
    @alert_rule = current_user.price_alerts.active.matching_rule(@rule_attributes).first
  end

  # sliced first so the path params (username, collection_id, page) are not logged as unpermitted
  def filter_params
    params.slice(*FILTER_PARAMS, :rarity).permit(*FILTER_PARAMS, rarity: [])
  end

  def first_page
    collection_movers_path(params[:username], collection_id: @scope[:collection]&.id,
                                              **filter_params.to_h.symbolize_keys)
  end
end
