# "Who is trading this": one want off the signed-in user's list, and everyone with a copy of it
# marked for trade. WantList::Traders does the matching and ordering.
#
# Session-scoped like the matches page - the want is only ever looked up through current_user's own
# list, so somebody else's want id reads the same as one that was removed.
#
# The list sits in a turbo frame so pagination swaps it in place, which is also what lets the request
# spec ask for it without the layout.
class WantTradersController < ApplicationController
  before_action :authenticate_user!
  before_action :load_want

  def show
    result = WantList::Traders.call(want: @want)
    @pagy, offers = pagy(:offset, result[:offers], count: result[:total], limit: WantList::Traders::PER_PAGE)
    # a page past the end reads as "nobody" - start over
    return redirect_to want_traders_path(@want) if offers.empty? && @pagy.page > 1

    @traders = WantList::Traders.present(offers.to_a)
    @trader_count = result[:traders]
  end

  private

  def load_want
    @want = current_user.want_list_items.includes(magic_card: :boxset).find_by(id: params[:id])
    return if @want

    redirect_to collection_wants_path(current_user.username), alert: 'That card is not on your want list.'
  end
end
