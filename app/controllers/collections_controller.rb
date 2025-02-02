class CollectionsController < ApplicationController
  require 'pagy/extras/array'

  def new
    @collection = Collection.new

    render :new
  end

  def create
    collection = Collection.new(collection_params)

    collection.save ? redirect_to(root_path) : render(:new, status: :unprocessable_entity)
  end

  def show
    user = User.find_by(username: params[:username])
    return render :not_found unless user

    setup_collections(user)
    search_magic_cards

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
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
    Boxset.where(id: boxset_ids).map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end
  end

  private

  def setup_collections(user)
    @collection = load_collection
    @collections_value = user.collections.sum(:total_value)
    @collections = user.collections.order(:id)
    @options = boxset_options(user)
  end

  def search_magic_cards
    magic_cards = Search::Collection.call(
      collection: @collection,
      search_term: params[:search],
      code: params[:code],
      sort_by: :price
    )
    @pagy, @magic_cards = pagy_array(magic_cards)
  end

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
