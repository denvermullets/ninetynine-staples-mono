class PreconDecksController < ApplicationController
  before_action :set_precon_deck, only: %i[show import_to_collection]

  def index
    @deck_types = PreconDeck.ingested.distinct.pluck(:deck_type).compact.sort
    @selected_type = params[:deck_type]
    @card_search = params[:card_search]

    decks = PreconDeck.ingested.by_type(@selected_type)
    decks = search_by_card(decks) if @card_search.present?

    @pagy, @precon_decks = pagy(decks.order(:name), items: 50)
  end

  def show
    @precon_deck = PreconDeck.includes(precon_deck_cards: :magic_card).find(params[:id])
    @collections = current_user&.ordered_collections || []
  end

  def import_to_collection
    unless current_user
      redirect_to login_path, alert: 'Please log in to import decks'
      return
    end

    # Validate: must have collection_id OR collection_name
    if params[:collection_id].blank? && params[:collection_name].blank?
      redirect_to precon_deck_path(@precon_deck),
                  alert: 'Please enter a collection name or select an existing collection.'
      return
    end

    collection = find_or_create_collection

    result = PreconDeckImporter.call(
      precon_deck: @precon_deck,
      collection: collection
    )

    redirect_to collection_show_path(current_user.username, collection),
                notice: "#{@precon_deck.name} imported successfully! (#{result[:cards_imported]} cards)"
  end

  private

  def set_precon_deck
    @precon_deck = PreconDeck.find(params[:id])
  end

  def find_or_create_collection
    if params[:collection_id].present?
      current_user.collections.find(params[:collection_id])
    else
      current_user.collections.create!(
        name: params[:collection_name],
        description: 'Preconstructed deck'
      )
    end
  end

  def search_by_card(decks)
    decks.joins(precon_deck_cards: :magic_card)
         .where('magic_cards.name ILIKE ?', "%#{@card_search}%")
         .distinct
  end
end
