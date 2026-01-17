class BoxsetsController < ApplicationController
  def index
    setup_index_defaults
    load_boxset_for_index
  end

  def load_boxset
    return handle_empty_params if params[:code].blank? && params[:search].blank?

    @boxset = determine_boxset
    load_cards_with_view_mode

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  private

  def setup_index_defaults
    @options = build_boxset_options
    @default_code = set_default_boxset
    @view_mode = params[:view_mode] || 'table'
    @grouping = params[:grouping] || 'none'
    @grouping_allowed = false
  end

  def load_boxset_for_index
    if params[:code].present? || params[:search].present?
      load_boxset
    elsif @default_code.present?
      load_default_boxset
    end
  end

  def search_magic_cards
    # Start with all cards if "All" is selected, otherwise use boxset cards
    @cards = @boxset.present? ? @boxset.magic_cards : MagicCard.all
    @cards = search_cards
    # Exclude only 'b' side cards, but keep cards where card_side is NULL or 'a'
    @cards = @cards.where("card_side IS NULL OR card_side != 'b'")
    @cards = filter_by_price if params[:valuable_only] == 'true' # Apply price filter before color filtering
    @cards = filter_cards
    CollectionQuery::Sort.call(cards: @cards, sort_by: :id)
  end

  def search_cards
    CollectionQuery::Search.call(
      cards: @cards, search_term: params[:search], boxset_id: @boxset&.id, collection_id: nil
    )
  end

  def filter_cards
    CollectionQuery::Filter.call(cards: @cards, params: params)
  end

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end

  def filter_by_price
    minimum_price = 0.80
    @cards.where('normal_price > ? OR foil_price > ?', minimum_price, minimum_price)
  end

  def build_boxset_options
    [
      { id: 'all', name: 'All Cards', code: 'all', keyrune_code: 'pmtg1' }
    ] + Boxset.all_sets.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end
  end

  def set_default_boxset
    return nil unless params[:code].blank? && params[:search].blank?

    Boxset.released_sets.first&.code
  end

  def load_default_boxset
    @boxset = fetch_boxset(@default_code)
    load_cards_with_view_mode if @boxset.present?
  end

  def load_cards_with_view_mode
    @view_mode = params[:view_mode] || 'table'
    @grouping = params[:grouping] || 'none'
    @grouping_allowed = @boxset.present? # Only allow grouping when a specific boxset is selected

    cards = search_magic_cards

    if skip_pagination?
      @magic_cards = cards.to_a
      @grouped_cards = Collections::GroupCards.call(cards: @magic_cards, grouping: @grouping)
      @pagy = nil
    else
      @pagy, @magic_cards = pagy(:offset, cards, items: 50)
    end
  end

  def skip_pagination?
    @view_mode == 'visual' && @grouping != 'none' && @grouping_allowed
  end

  def handle_empty_params
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to root_path }
    end
  end

  def determine_boxset
    return nil if params[:code] == 'all'

    fetch_boxset(params[:code])
  end
end
