# rubocop:disable Metrics/ClassLength
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

  def overview
    @user = User.find_by!(username: params[:username])
    @is_owner = current_user&.id == @user.id
    @collections = @is_owner ? current_user.ordered_collections : @user.collections.visible_to_public.order(:id)
    @regular_collections = @collections.reject { |c| Collection.deck_type?(c.collection_type) }
    @deck_collections = @collections.select { |c| Collection.deck_type?(c.collection_type) }
  end

  def show
    @user = User.find_by!(username: params[:username])
    @is_owner = current_user&.id == @user.id

    if params[:collection_id].present?
      collection = Collection.find_by(id: params[:collection_id])
      if collection&.hidden? && !@is_owner
        redirect_to root_path, alert: 'This collection is private'
        return
      end
    end

    @collection_type = nil
    setup_collections(@collection_type)
    search_magic_cards
    setup_view_mode

    render 'index'
  end

  def show_decks
    @user = User.find_by!(username: params[:username])
    @is_owner = current_user&.id == @user.id

    if params[:collection_id].present?
      collection = Collection.find_by(id: params[:collection_id])
      if collection&.hidden? && !@is_owner
        redirect_to root_path, alert: 'This deck is private'
        return
      end
    end

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
      params.require(:collection).permit(:description, :name, :collection_type, :user_id, :is_public)
    else
      params.permit(:description, :name, :collection_type, :is_public)
    end
  end

  def setup_view_mode
    @view_mode = params[:view_mode] || 'table'
    @grouping = params[:grouping] || 'none'
    @grouping_allowed = params[:code].present?

    unless @filtered_cards.present?
      @magic_cards = []
      return
    end

    paginate_cards
    load_visual_mode_data if @view_mode == 'visual'
  end

  def paginate_cards
    skip = @view_mode == 'visual' && @grouping != 'none' && @grouping_allowed
    @pagy, @magic_cards = skip ? [nil, @filtered_cards.to_a] : pagy(:offset, @filtered_cards)
  end

  def load_visual_mode_data
    result = Collections::VisualModeSetup.call(cards: @magic_cards, user: @user, grouping: @grouping)
    @aggregated_quantities = result[:aggregated_quantities]
    @grouped_cards = result[:grouped_cards]
  end
end
# rubocop:enable Metrics/ClassLength
