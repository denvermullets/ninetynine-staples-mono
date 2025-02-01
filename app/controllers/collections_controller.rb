class CollectionsController < ApplicationController
  require 'pagy/extras/array'

  def new
    @collection = Collection.new

    render :new
  end

  def create
    collection = Collection.new(collection_params)

    if collection.save
      flash[:success] = "Created a new collection named #{collection.name} to your account."
      redirect_to root_path
    else
      flash.now[:error] = 'Failed to create collection.'
      render :new, status: :unprocessable_entity
    end
  end

  def show
    # case sensitive for now
    user = User.find_by(username: params[:username])

    if user.present?
      @collection = load_collection
      @collections_value = user.collections.sum(:total_value)
      @collections = user.collections
      boxset_options(user)
      magic_cards = Search::Collection.call(
        collection: @collection, search_term: params[:search], code: params[:code],
        sort_by: :price
      )

      @pagy, @magic_cards = pagy_array(magic_cards)

      respond_to do |format|
        format.turbo_stream
        format.html { render 'index' }
      end
    else
      render :not_found
    end
  end

  def load
    magic_cards = Search::Collection.call(
      collection: load_collection, search_term: params[:search], code: params[:code],
      sort_by: :price
    )

    @pagy, @magic_cards = pagy_array(magic_cards)

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end

  def boxset_options(user)
    # just get the boxset_id's for cards in the collection and create the options list from that
    boxset_ids = load_collection_ids(user.collections)
    boxsets = Boxset.where(id: boxset_ids)
    @options = boxsets.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end
  end

  private

  def load_collection_ids(collections)
    if params[:collection_id].present?
      collections.find_by(id: params[:collection_id]).magic_cards.pluck(:boxset_id).uniq.compact
    else
      collections.first.magic_cards.pluck(:boxset_id).uniq.compact
    end
  end

  def load_collection
    if params[:collection_id].present?
      Collection.find(params[:collection_id])
    else
      User.find_by(username: params[:username]).collections.first
    end
  end

  def collection_params
    params.require(:collection).permit(:description, :name, :collection_type, :user_id)
  end
end
