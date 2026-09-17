# A user's trade list: every copy marked for trade across their public collections, priced.
#
# Not authenticated, same as the proxies and reserved pages - CollectionTrades::Access decides who may
# look, and an open list is readable logged out. current_user is who is looking, never whose cards
# are listed.
#
# The list lives in a turbo frame with turbo_action advance, so the finish and sort pills, the search
# form and the pagination all swap the table and move the URL without an endpoint of their own.
class CollectionTradesController < ApplicationController
  PER_PAGE = 50

  def show
    access = CollectionTrades::Access.call(username: params[:username], viewer: current_user)
    return redirect_to root_path, alert: 'This trade list is private' unless access[:visible]

    @user = access[:user]
    @owner = access[:owner]
    read_options
    load_list
  end

  private

  def read_options
    @search = params[:search].to_s.strip.presence
    @finish = requested(:finish, CollectionTrades::List::FINISHES, 'all')
    @sort = requested(:sort, CollectionTrades::List::SORTS.keys, 'value')
  end

  def requested(param, allowed, fallback)
    allowed.include?(params[param]) ? params[param] : fallback
  end

  # counted once and handed to pagy as :count, then PageRows runs the page - the same two steps
  # CollectionsController#setup_view_mode takes, for the same grouped-relation reasons
  def load_list
    list = CollectionTrades::List.call(user: @user, viewer: current_user, search: @search,
                                       finish: @finish, sort: @sort)
    @counts = list[:counts]
    @totals = list[:totals]

    total = CollectionQuery::TotalCount.call(cards: list[:cards])
    @pagy, @cards = total.zero? ? [nil, []] : paginate(list[:cards], total)
  end

  def paginate(cards, total)
    pagy, page = pagy(:offset, cards, count: total, limit: PER_PAGE)

    [pagy, CollectionQuery::PageRows.call(cards: page, preloads: %i[boxset])]
  end
end
