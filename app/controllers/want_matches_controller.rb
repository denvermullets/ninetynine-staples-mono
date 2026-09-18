# "Who has my wants": the signed-in user's want list matched against everyone else's public
# collections, one panel per holder. WantList::Matches does the matching, ranking and paging; this
# only hands it the page and wraps its total for Pagy.
#
# Session-scoped like the trade builder it leads into - there is no username in the path, because
# the only want list this page is ever about is current_user's. Their want list does not need to be
# public for it: the wants are their own.
#
# The list sits in a turbo frame so pagination swaps it in place, which is also what lets the request
# spec ask for it without the layout.
class WantMatchesController < ApplicationController
  before_action :authenticate_user!

  def show
    page = [params[:page].to_i, 1].max
    result = WantList::Matches.call(user: current_user, page: page)
    # the total rides on the ranked rows, so a page past the end reads as "no matches" - start over
    return redirect_to want_matches_path if result[:users].empty? && page > 1

    @matches = result[:users]
    @total = result[:total]
    @pagy = Pagy::Offset.new(count: @total, page: page, limit: WantList::Matches::PER_PAGE, request: request)
  end
end
