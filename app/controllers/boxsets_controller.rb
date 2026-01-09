class BoxsetsController < ApplicationController
  def index
    @options = build_boxset_options
    @default_code = set_default_boxset
    load_default_boxset if params[:code].blank? && params[:search].blank? && @default_code.present?
    load_boxset if params[:code].present? || params[:search].present?
  end

  def load_boxset
    return handle_empty_params if params[:code].blank? && params[:search].blank?

    @boxset = determine_boxset
    @pagy, @magic_cards = pagy(:offset, search_magic_cards, items: 50)

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  private

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
    # split comma-separated values into arrays for OR filtering
    rarities = params[:rarity]&.flat_map { |r| r.split(',') }&.compact_blank
    colors = params[:mana]&.flat_map { |c| c.split(',') }&.compact_blank

    # Parse price change range
    price_change_min, price_change_max = parse_price_change_range

    CollectionQuery::Filter.call(
      cards: @cards,
      code: nil,
      collection_id: nil,
      rarities: rarities,
      colors: colors,
      price_change_min: price_change_min,
      price_change_max: price_change_max
    )
  end

  def parse_price_change_range
    return [nil, nil] if params[:price_change_range].blank?

    min, max = params[:price_change_range].split(',').map(&:to_f)
    [min, max]
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
    @pagy, @magic_cards = pagy(:offset, search_magic_cards, items: 50) if @boxset.present?
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
