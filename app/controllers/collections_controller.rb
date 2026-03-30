class CollectionsController < ApplicationController
  before_action :authenticate_user!, only: %i[edit_collection_modal update destroy confirm_destroy_deck destroy_deck]
  before_action :set_collection, only: %i[edit_collection_modal update destroy confirm_destroy_deck destroy_deck]
  before_action :ensure_owner, only: %i[edit_collection_modal update destroy confirm_destroy_deck destroy_deck]
  before_action :set_user_and_ownership, only: %i[show show_decks overview]
  before_action :enforce_visibility, only: %i[show show_decks]

  def new
    @collection = Collection.new
    render :new
  end

  def create
    collection = Collection.new(collection_params)
    unless collection.save
      render :new, status: :unprocessable_entity
      return
    end

    path = Collection.deck_type?(collection.collection_type) ? decks_index_path(current_user.username) : root_path
    redirect_to path
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

  def destroy
    unless @collection.deletable?
      redirect_back fallback_location: root_path, alert: 'Cannot delete a deck that has finalized cards'
      return
    end

    @collection.collection_magic_cards.destroy_all
    @collection.destroy

    if Collection.deck_type?(@collection.collection_type)
      redirect_to decks_index_path(current_user.username), notice: 'Deck deleted successfully'
    else
      redirect_to root_path, notice: 'Collection deleted successfully'
    end
  end

  def confirm_destroy_deck
    render partial: 'deck_builder/confirm_modal', locals: {
      title: 'Delete Deck', confirm_text: 'Delete Deck', turbo_frame: 'deck_modal', danger: true,
      message: 'Are you sure? This will permanently delete this deck and all cards in it from your collection.',
      confirm_url: destroy_deck_collection_path(@collection), confirm_method: :delete
    }
  end

  def destroy_deck
    DestroyDeckJob.perform_later(@collection.id, current_user.id)
    toast_html = ApplicationController.render(
      partial: 'shared/broadcast_toast',
      locals: { message: "\"#{@collection.name}\" queued for deletion", type: 'success' }
    )
    render turbo_stream: [turbo_stream.replace('deck_modal', ''), turbo_stream.append('toasts', toast_html)]
  end

  def overview
    @collections = if @is_owner
                     current_user.ordered_collections
                   else
                     @user.collections.includes(:cover_card).visible_to_public.order(:id)
                   end
    @deck_collections, @regular_collections = @collections.partition { |c| Collection.deck_type?(c.collection_type) }
  end

  def show
    setup_collections(nil)
    search_and_setup_view
  end

  def show_decks
    @collection_type = 'deck'
    setup_collections(nil, use_deck_scope: true)
    search_and_setup_view
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

  def set_user_and_ownership
    @user = User.find_by!(username: params[:username])
    @is_owner = current_user&.id == @user.id
  end

  def enforce_visibility
    return unless params[:collection_id].present?

    collection = Collection.find_by(id: params[:collection_id])
    return unless collection&.hidden? && !@is_owner

    alert = Collection.deck_type?(collection.collection_type) ? 'This deck is private' : 'This collection is private'
    redirect_to root_path, alert: alert
  end

  def search_and_setup_view
    search_magic_cards
    setup_view_mode
    render 'index'
  end

  def setup_collections(collection_type, use_deck_scope: false)
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

  def set_collection = @collection = Collection.find(params[:id])

  def ensure_owner
    redirect_to root_path, alert: 'Access denied' unless @collection.user_id == current_user.id
  end

  def collection_params
    if params[:collection].present?
      params.require(:collection).permit(:description, :name, :collection_type, :user_id, :is_public, :cover_card_id)
    else
      params.permit(:description, :name, :collection_type, :is_public, :cover_card_id)
    end
  end

  def setup_view_mode
    view = Collections::ViewMode.new(filtered_cards: @filtered_cards, user: @user, params: params)
    result = view.call
    @view_mode = result[:view_mode]
    @grouping = result[:grouping]
    @grouping_allowed = result[:grouping_allowed]
    @aggregated_quantities = result[:aggregated_quantities]
    @grouped_cards = result[:grouped_cards]

    if result[:magic_cards].empty? || view.skip_pagination?
      @pagy = nil
      @magic_cards = result[:magic_cards].empty? ? [] : @filtered_cards.to_a
    else
      @pagy, @magic_cards = pagy(:offset, @filtered_cards)
    end
  end
end
