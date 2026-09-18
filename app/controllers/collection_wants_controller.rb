# A user's want list: every card they are looking for, priced, with the ones they have since picked
# up called out.
#
# Not authenticated, same as the trade list - WantList::Access decides who may look, and an open list
# is readable logged out. current_user is who is looking, never whose wants are listed.
#
# The list lives in a turbo frame with turbo_action advance, so the pills and the pagination swap it
# and move the URL. The owner's edit and remove forms post to WantListItemsController with
# return_to=want_list, which redirects back here; the frame reloads with fresh counts.
class CollectionWantsController < ApplicationController
  PER_PAGE = 50

  def show
    access = WantList::Access.call(username: params[:username], viewer: current_user)
    return redirect_to root_path, alert: 'This want list is private' unless access[:visible]

    @user = access[:user]
    @owner = access[:owner]
    read_options
    load_list(access[:collection_ids])
  end

  private

  def read_options
    @filter = requested(:filter, WantList::List::FILTERS, 'all')
    @sort = requested(:sort, WantList::List::SORTS.keys, 'name')
  end

  def requested(param, allowed, fallback)
    allowed.include?(params[param]) ? params[param] : fallback
  end

  # the pill counts already know the total, and handing it to pagy keeps it from counting a relation
  # whose select carries a subquery
  def load_list(collection_ids)
    list = WantList::List.call(user: @user, collection_ids: collection_ids, filter: @filter, sort: @sort)
    @counts = list[:counts]

    total = @counts[@filter.to_sym]
    @pagy, @items = total.zero? ? [nil, []] : pagy(:offset, list[:items], count: total, limit: PER_PAGE)
  end
end
