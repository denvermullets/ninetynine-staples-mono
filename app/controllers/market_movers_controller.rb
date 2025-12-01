class MarketMoversController < ApplicationController
  def index
    @user = current_user
    return redirect_to root_path, alert: 'Please sign in to view market movers.' unless @user

    magic_cards = MarketMovers::FetchValuableCommons.call(user: @user)
    @pagy, @magic_cards = pagy(:offset, magic_cards, items: 50)
    @collections = @user.collections

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end
end
