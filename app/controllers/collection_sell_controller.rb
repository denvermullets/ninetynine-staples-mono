# The cards Card Kingdom is buying, as a pull list - CollectionStats::SellList on a page.
#
# Owner only, unlike the movers page it sits beside: a sell list is something you act on, and a
# visitor cannot pull cards out of somebody else's binders. Anyone else's username is a 404 rather
# than a redirect, so the page does not confirm what it would have shown.
#
# Same shape as CollectionMoversController: SellList whitelists the filters and pages itself, and
# the filters and table share one turbo frame with turbo_action advance, so every view is a URL.
class CollectionSellController < ApplicationController
  FILTER_PARAMS = %i[payment finish decks min_buylist max_buylist sort dir].freeze

  before_action :authenticate_user!

  def show
    @scope = CollectionStats::Scope.call(username: params[:username], viewer: current_user,
                                         collection_id: params[:collection_id])
    return head :not_found unless @scope[:owner]
    return bounce_to_whole_collection if @scope[:missing]
    return if @scope[:collection_ids].empty?

    load_list
    # the total counts every page, so an empty page past the end is a stale link - start it over
    redirect_to first_page if @rows.empty? && @pagy.page > 1
  end

  private

  # Dropping the collection_id rather than keeping it, or the redirect would loop
  def bounce_to_whole_collection
    redirect_to collection_sell_path(params[:username]), alert: 'Collection not found'
  end

  def load_list
    result = CollectionStats::SellList.call(collection_ids: @scope[:collection_ids], filters: filter_params,
                                            page: params[:page])

    @filters = result[:filters]
    @rows = result[:rows]
    @total = result[:total]
    @copies = result[:copies]
    @payout = result[:payout]
    @pagy = Pagy::Offset.new(count: @total, page: result[:page], limit: result[:per_page], request: request)
  end

  # sliced first so the path params (username, collection_id, page) are not logged as unpermitted
  def filter_params
    params.slice(*FILTER_PARAMS, :rarity).permit(*FILTER_PARAMS, rarity: [])
  end

  def first_page
    collection_sell_path(params[:username], collection_id: @scope[:collection]&.id,
                                            **filter_params.to_h.symbolize_keys)
  end
end
