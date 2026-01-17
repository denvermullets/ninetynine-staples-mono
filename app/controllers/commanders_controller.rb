class CommandersController < ApplicationController
  SORT_COLUMNS = %w[name card_type mana_value edhrec_rank edhrec_saltiness].freeze

  helper_method :sort_params

  def index
    @options = build_boxset_options
    @default_code = params[:code]
    @sort_column = sort_column
    @sort_direction = sort_direction
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
    @cards = CollectionQuery::Search.call(cards: @cards, search_term: params[:search], boxset_id: @boxset&.id)
    @cards = @cards.where("card_side IS NULL OR card_side != 'b'")
    @cards = filter_cards
    @cards = CollectionQuery::Deduplicate.call(cards: @cards, column: :name, prefer_by: :edhrec_rank)
    CollectionQuery::ColumnSort.call(cards: @cards, column: @sort_column, direction: @sort_direction)
  end

  def base_commander_query
    MagicCard.where(can_be_commander: true)
  end

  def filter_by_boxset
    @cards.where(boxset_id: @boxset.id)
  end

  def filter_by_owned
    @cards.joins(collection_magic_cards: :collection)
          .where(collections: { user_id: current_user.id })
  end

  def filter_cards
    rarities = params[:rarity]&.flat_map { |r| r.split(',') }&.compact_blank
    colors = params[:mana]&.flat_map { |c| c.split(',') }&.compact_blank

    CollectionQuery::Filter.call(
      cards: @cards,
      code: nil,
      collection_id: nil,
      rarities: rarities,
      colors: colors
    )
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

    Boxset.find_by(code: params[:code])
  end

  def load_default_commanders
    @pagy, @magic_cards = pagy(:offset, search_commanders, items: 50)
  end

  def sort_column
    SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : 'name'
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
