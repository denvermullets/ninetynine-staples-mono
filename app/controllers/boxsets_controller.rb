class BoxsetsController < ApplicationController
  # card_number is the default and has no clickable heading - it's the set order the table opens in
  SORT_COLUMNS = %w[card_number name normal_price foil_price].freeze
  # SortConfig builds the header links from only these keys. page is excluded on purpose -
  # sorting starts over from the first page
  PRESERVE_PARAMS = %i[
    code search rarity mana view_mode grouping valuable_only exact_color_match price_change_range
  ].freeze

  helper_method :sort_config, :sort_link_params

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
    @collections = current_user&.ordered_collections || []
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
    # Sort returns a relation, not an Array - keep it that way so pagy can push the LIMIT/OFFSET
    # down to Postgres instead of us instantiating every row in the set to render one page
    sort_cards
  end

  def sort_cards
    return CollectionQuery::Sort.call(cards: @cards, sort_by: :id) if sort_config.column == 'card_number'

    # prices and names repeat, so id is the tiebreak that keeps pages from overlapping
    CollectionQuery::ColumnSort.call(
      records: @cards, column: sort_config.column, direction: sort_config.direction, table_name: 'magic_cards'
    ).order('magic_cards.id' => :asc)
  end

  # the default boxset loads with no code in the URL, and load_boxset ignores a request
  # without one, so the link always names the set on screen
  def sort_link_params(column)
    sort_config.link_params(column).merge(code: @boxset&.code || 'all')
  end

  def sort_config
    @sort_config ||= CollectionQuery::SortConfig.new(
      params: params, allowed_columns: SORT_COLUMNS, preserve_params: PRESERVE_PARAMS
    )
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

    Boxset.find_by(code: code)
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
      @magic_cards = preload_grouped(cards).to_a
      @grouped_cards = Collections::GroupCards.call(cards: @magic_cards, grouping: @grouping)
      @pagy = nil
    else
      @pagy, page = pagy(:offset, cards, items: 50)
      @magic_cards = preload_page(page)
    end
  end

  def skip_pagination?
    @view_mode == 'visual' && @grouping != 'none' && @grouping_allowed
  end

  # the visual card reads no associations, so this branch only pays for what GroupCards itself
  # touches - grouping by color calls card.colors per card, and on an unloaded association each
  # empty?/size/first is its own query. Grouping by rarity just reads a column
  def preload_grouped(cards)
    return cards unless @grouping == 'color'

    cards.preload(:colors)
  end

  # preloaded on the page, never on the filtered relation - preloading before pagy would
  # instantiate the whole set to render 50 rows. The table and its mobile partial read
  # card.boxset.keyrune_code and the finish predicates on every row; the visual card reads
  # neither, so it doesn't pay for it
  def preload_page(page)
    return page if @view_mode == 'visual'

    page.preload(:boxset, :finishes)
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
