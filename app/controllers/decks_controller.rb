class DecksController < ApplicationController
  def index
    @user = User.find_by!(username: params[:username])
    @listing = Decks::Listing.call(user: @user, viewer: current_user, sort: params[:sort], group_by: params[:group_by])
    @is_owner = @listing.is_owner
    @sort_options = Decks::Listing::SORT_OPTIONS
  end
end
