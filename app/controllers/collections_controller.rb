class CollectionsController < ApplicationController
  def new
    @collection = Collection.new

    render :new
  end

  def create
    collection = Collection.new(collection_params)

    collection.save ? redirect_to(root_path) : render(:new, status: :unprocessable_entity)
  end

  def show
    @user = User.find_by(username: params[:username])
    return render :not_found unless @user

    @collection_type = nil
    setup_collections(@collection_type)
    search_magic_cards

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  def show_decks
    @user = User.find_by(username: params[:username])
    return render :not_found unless @user

    @collection_type = 'deck'
    setup_collections(nil, use_deck_scope: true)
    search_magic_cards

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  def load
    return render :not_found unless params[:username].present?

    @user = User.find_by(username: params[:username])
    @collection_type = params[:collection_type]
    setup_collections(@collection_type)
    search_magic_cards

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end

  private

  def boxset_options
    # just get the boxset_id's for cards in the collection and create the options list from that
    boxset_ids = load_collection_ids(@user.collections)
    Boxset.where(id: boxset_ids).map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end
  end

  def setup_collections(collection_type = nil, use_deck_scope: false)
    result = Collections::Setup.call(
      user: @user, current_user: current_user, collection_id: params[:collection_id],
      collection_type: collection_type, use_deck_scope: use_deck_scope
    )
    @collection = result[:collection]
    @collections = result[:collections]
    @collections_value = result[:collections_value]
    @collection_history = result[:collection_history]
    @options = boxset_options
  end

  def search_magic_cards
    return if @user.nil?

    magic_cards = Search::Collection.call(
      cards: load_collection,
      search_term: params[:search],
      code: params[:code],
      sort_by: :price,
      collection_id: params[:collection_id] || nil
    )

    magic_cards = filter_cards(magic_cards)

    @pagy, @magic_cards = pagy(:offset, magic_cards)
  end

  def filter_cards(cards)
    rarities = params[:rarity]&.flat_map { |r| r.split(',') }&.compact_blank
    colors = params[:mana]&.flat_map { |c| c.split(',') }&.compact_blank

    CollectionQuery::Filter.call(
      cards: cards, code: nil, collection_id: nil, rarities: rarities, colors: colors
    )
  end

  def load_collection
    MagicCard
      .joins(collection_magic_cards: :collection)
      .where(collections: { user_id: @user.id })
  end

  def load_collection_ids(collections)
    if params[:collection_id].present?
      collections.find_by(id: params[:collection_id]).magic_cards.pluck(:boxset_id).uniq.compact
    else
      collections.map { |col| col.magic_cards.pluck(:boxset_id) }.uniq.compact.flatten
    end
  end

  def collection_params
    params.require(:collection).permit(:description, :name, :collection_type, :user_id)
  end
end
