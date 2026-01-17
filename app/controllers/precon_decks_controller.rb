class PreconDecksController < ApplicationController
  SORT_COLUMNS = %w[name deck_type release_date code].freeze

  before_action :set_precon_deck, only: %i[show import_to_collection]

  def index
    @deck_types = PreconDeck.ingested.distinct.pluck(:deck_type).compact.sort
    @selected_type = params[:deck_type]
    @card_search = params[:card_search]
    @sort_column = sort_column
    @sort_direction = sort_direction

    decks = PreconDeck.ingested.by_type(@selected_type)
    decks = search_by_card(decks) if @card_search.present?
    decks = CollectionQuery::ColumnSort.call(records: decks, column: @sort_column, direction: @sort_direction)

    @pagy, @precon_decks = pagy(decks, items: 50)
  end

  def show
    load_precon_deck_with_cards
    set_view_options

    all_cards = @precon_deck.precon_deck_cards.to_a
    @grouped_cards = PreconDecks::GroupCards.call(cards: all_cards, grouping: @grouping, sort_by: @sort_by)
    @stats = build_stats(all_cards)

    respond_to_show
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

  def load_precon_deck_with_cards
    @precon_deck = PreconDeck.includes(precon_deck_cards: { magic_card: %i[boxset colors magic_card_color_idents] })
                             .find(params[:id])
    @collections = current_user&.ordered_collections || []
  end

  def set_view_options
    @view_mode = params[:view_mode] || 'list'
    @grouping = params[:grouping] || 'type'
    @sort_by = params[:sort_by] || 'mana_value'
  end

  def respond_to_show
    respond_to do |format|
      format.html
      format.turbo_stream { render turbo_stream: turbo_stream.update('deck_cards', partial: 'deck_cards') }
    end
  end

  def find_or_create_collection
    if params[:collection_id].present?
      current_user.collections.find(params[:collection_id])
    else
      current_user.collections.create!(
        name: params[:collection_name],
        description: "Preconstructed #{@precon_deck.deck_type} deck",
        collection_type: collection_type_from_precon
      )
    end
  end

  def collection_type_from_precon
    return 'deck' if @precon_deck.deck_type.blank?

    # Convert "Commander" -> "commander_deck", "Duel Commander" -> "duel_commander_deck"
    "#{@precon_deck.deck_type.parameterize.underscore}_deck"
  end

  def search_by_card(decks)
    decks.joins(precon_deck_cards: :magic_card)
         .where('magic_cards.name ILIKE ?', "%#{@card_search}%")
         .distinct
  end

  def build_stats(cards)
    {
      total: cards.sum(&:quantity),
      value: cards.sum { |c| c.quantity * (c.magic_card.normal_price || 0).to_f }
    }
  end

  def sort_column
    SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
  end
end
