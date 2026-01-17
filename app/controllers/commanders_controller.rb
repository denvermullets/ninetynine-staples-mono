class CommandersController < ApplicationController
  SORT_COLUMNS = %w[name card_type mana_value edhrec_rank edhrec_saltiness].freeze
  PRESERVE_PARAMS = %i[code search owned_only rarity mana].freeze

  helper_method :sort_config

  def index
    @options = build_boxset_options
    @default_code = params[:code]
    @boxset = determine_boxset
    load_default_commanders
  end

  def load_commanders
    @options = build_boxset_options
    @boxset = determine_boxset
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
    CollectionQuery::ColumnSort.call(cards: @cards, column: sort_config.column, direction: sort_config.direction)
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
    CollectionQuery::Filter.call(cards: @cards, params: params)
  end

  def build_boxset_options
    Rails.cache.fetch('commanders/boxset_options', expires_in: 1.hour) do
      boxsets_with_commanders = Boxset.joins(:magic_cards)
                                      .where(magic_cards: { can_be_commander: true })
                                      .distinct
                                      .order(release_date: :desc)

      [
        { id: 'all', name: 'All Commanders', code: 'all', keyrune_code: 'pmtg1' }
      ] + boxsets_with_commanders.map do |boxset|
        keyrune = boxset.keyrune_code&.downcase || 'default'
        { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: keyrune }
      end
    end
  end

  def determine_boxset
    return nil if params[:code] == 'all' || params[:code].blank?

    Boxset.find_by(code: params[:code])
  end

  def load_default_commanders
    @pagy, @magic_cards = pagy(:offset, search_commanders, items: 50)
  end

  def sort_config
    @sort_config ||= CollectionQuery::SortConfig.new(
      params: params,
      allowed_columns: SORT_COLUMNS,
      default_column: 'name',
      preserve_params: PRESERVE_PARAMS
    )
  end
end
