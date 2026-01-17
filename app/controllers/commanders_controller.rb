class CommandersController < ApplicationController
  helper_method :sort_params

  def index
    @options = build_boxset_options
    @default_code = params[:code]
    @sort_column = sort_column
    @sort_direction = sort_direction
    # Always load commanders (show all by default)
    load_default_commanders
  end

  def load_commanders
    @options = build_boxset_options
    @boxset = determine_boxset
    @sort_column = sort_column
    @sort_direction = sort_direction
    @pagy, @magic_cards = pagy(:offset, search_commanders, items: 50)

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  private

  def search_commanders
    @cards = base_commander_query
    @cards = filter_by_boxset if @boxset.present?
    @cards = filter_by_owned if params[:owned_only] == 'true' && current_user
    @cards = search_cards
    @cards = @cards.where("card_side IS NULL OR card_side != 'b'")
    @cards = filter_cards
    apply_sorting
  end

  def base_commander_query
    MagicCard.where(can_be_commander: true)
             .includes(:boxset, :finishes, magic_card_color_idents: :color)
  end

  def filter_by_boxset
    @cards.where(boxset_id: @boxset.id)
  end

  def filter_by_owned
    # Don't use distinct here - deduplication happens in apply_sorting
    @cards.joins(collection_magic_cards: :collection)
          .where(collections: { user_id: current_user.id })
  end

  def search_cards
    CollectionQuery::Search.call(
      cards: @cards, search_term: params[:search], boxset_id: @boxset&.id, collection_id: nil
    )
  end

  def filter_cards
    rarities = params[:rarity]&.flat_map { |r| r.split(',') }&.compact_blank
    colors = params[:mana]&.flat_map { |c| c.split(',') }&.compact_blank

    CollectionQuery::Filter.call(
      cards: @cards,
      code: nil,
      collection_id: nil,
      rarities: rarities,
      colors: colors,
      price_change_min: nil,
      price_change_max: nil
    )
  end

  def apply_sorting
    direction = @sort_direction == 'desc' ? 'DESC' : 'ASC'

    # Get unique commanders by name (one printing per commander)
    unique_cards = deduplicate_by_name

    case @sort_column
    when 'edhrec_rank', 'edhrec_saltiness', 'mana_value'
      unique_cards.order(Arel.sql("#{@sort_column} #{direction} NULLS LAST"))
    else
      unique_cards.order("#{@sort_column} #{direction}")
    end
  end

  def deduplicate_by_name
    # Subquery to get one card ID per unique name (preferring the one with best edhrec_rank)
    subquery = @cards.select('DISTINCT ON (magic_cards.name) magic_cards.id')
                     .order(Arel.sql('magic_cards.name, magic_cards.edhrec_rank ASC NULLS LAST'))

    MagicCard.where(id: subquery).includes(:boxset, :finishes, magic_card_color_idents: :color)
  end

  def build_boxset_options
    boxsets_with_commanders = Boxset.joins(:magic_cards)
                                    .where(magic_cards: { can_be_commander: true })
                                    .distinct
                                    .order(release_date: :desc)

    [
      { id: 'all', name: 'All Commanders', code: 'all', keyrune_code: 'pmtg1' }
    ] + boxsets_with_commanders.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code&.downcase || 'default' }
    end
  end

  def determine_boxset
    return nil if params[:code] == 'all' || params[:code].blank?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: params[:code])
  end

  def load_default_commanders
    @pagy, @magic_cards = pagy(:offset, search_commanders, items: 50)
  end

  def sort_column
    %w[name card_type mana_value edhrec_rank edhrec_saltiness].include?(params[:sort]) ? params[:sort] : 'name'
  end

  def sort_direction
    %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
  end

  def sort_params(column)
    {
      sort: column,
      direction: @sort_column == column && @sort_direction == 'asc' ? 'desc' : 'asc',
      code: params[:code],
      search: params[:search],
      owned_only: params[:owned_only],
      'rarity[]': params[:rarity],
      'mana[]': params[:mana]
    }.compact_blank
  end
end
