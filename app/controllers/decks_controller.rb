class DecksController < ApplicationController
  def index
    @user = User.find_by(username: params[:username])
    return render :not_found unless @user

    @decks = @user.collections.decks.order(updated_at: :desc)
    @is_owner = current_user&.id == @user.id
  end
end
