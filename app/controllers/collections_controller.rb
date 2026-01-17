class CollectionsController < ApplicationController
  before_action :authenticate_user!, only: %i[edit_collection_modal update]
  before_action :set_collection, only: %i[edit_collection_modal update]
  before_action :ensure_owner, only: %i[edit_collection_modal update]

  def new
    @collection = Collection.new

    render :new
  end

  def create
    collection = Collection.new(collection_params)

    collection.save ? redirect_to(root_path) : render(:new, status: :unprocessable_entity)
  end

  def edit_collection_modal
    render partial: 'collections/edit_collection_modal', locals: { collection: @collection }
  end

  def update
    if @collection.update(collection_params)
      redirect_back fallback_location: root_path, notice: 'Collection updated successfully'
    else
      redirect_back fallback_location: root_path, alert: 'Failed to update collection'
    end
  end

  def show
    @user = User.find_by!(username: params[:username])

    @collection_type = nil
    setup_collections(@collection_type)
    search_magic_cards
    setup_view_mode

    render 'index'
  end

  def show_decks
    @user = User.find_by!(username: params[:username])

    @collection_type = 'deck'
    setup_collections(nil, use_deck_scope: true)
    search_magic_cards
    setup_view_mode

    render 'index'
  end

  def load
    raise ActiveRecord::RecordNotFound unless params[:username].present?

    @user = User.find_by!(username: params[:username])
    @collection_type = params[:collection_type]
    setup_collections(@collection_type)
    search_magic_cards
    setup_view_mode

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end

  private

  def setup_collections(collection_type = nil, use_deck_scope: false)
    result = Collections::Setup.call(
      user: @user, current_user: current_user, collection_id: params[:collection_id],
      collection_type: collection_type, use_deck_scope: use_deck_scope
    )
    @collection = result[:collection]
    @collections = result[:collections]
    @collections_value = result[:collections_value]
    @collection_history = result[:collection_history]
    @options = Collections::BoxsetOptions.call(collections: @user.collections, collection_id: params[:collection_id])
  end

  def search_magic_cards
    return if @user.nil?

    cards = MagicCard.joins(collection_magic_cards: :collection).where(collections: { user_id: @user.id })
    searched = Search::Collection.call(
      cards: cards, search_term: params[:search], code: params[:code],
      sort_by: :price, collection_id: params[:collection_id]
    )
    @filtered_cards = CollectionQuery::Filter.call(cards: searched, params: params)
  end

  def set_collection
    @collection = Collection.find(params[:id])
  end

  def ensure_owner
    redirect_to root_path, alert: 'Access denied' unless @collection.user_id == current_user.id
  end

  def collection_params
    if params[:collection].present?
      params.require(:collection).permit(:description, :name, :collection_type, :user_id)
    else
      params.permit(:description, :name, :collection_type)
    end
  end

  def setup_view_mode
    @view_mode = params[:view_mode] || 'table'
    @grouping = params[:grouping] || 'none'
    @grouping_allowed = params[:code].present?

    return unless @filtered_cards.present?

    paginate_or_load_all
    setup_visual_mode_data if @view_mode == 'visual'
  end

  def paginate_or_load_all
    if skip_pagination?
      @magic_cards = @filtered_cards.to_a
      @pagy = nil
    else
      @pagy, @magic_cards = pagy(:offset, @filtered_cards)
    end
  end

  def skip_pagination?
    @view_mode == 'visual' && @grouping != 'none' && @grouping_allowed
  end

  def setup_visual_mode_data
    result = Collections::VisualModeSetup.call(cards: @magic_cards, user: @user, grouping: @grouping)
    @aggregated_quantities = result[:aggregated_quantities]
    @grouped_cards = result[:grouped_cards]
  end
end
