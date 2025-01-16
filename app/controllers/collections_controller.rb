class CollectionsController < ApplicationController

  def show
    user = User.find_by(username: params[:username])
    collection = Collection.where('LOWER(name) = ? AND user_id = ?', params[:binder], user.id)

    @options = load_boxset_names

    render 'boxsets/index'
  end
end
