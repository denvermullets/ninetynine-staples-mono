class CommandersController < ApplicationController
  SORT_COLUMNS = %w[name card_type mana_value edhrec_rank edhrec_saltiness].freeze
  PRESERVE_PARAMS = %i[code search owned_only rarity mana exact_color_match partner].freeze

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

  # Partner mode swaps the pool for the cards that pair onto the selected colours, by name so every
  # printing stays in play for the boxset and owned filters. Backgrounds come in here too - they are
  # half of a legal pair without being can_be_commander on their own.
  def base_commander_query
    return MagicCard.where(name: partner_pairs.keys) if partner_mode?

    MagicCard.where(can_be_commander: true)
  end

  def partner_mode?
    params[:partner] == 'true'
  end

  def partner_pairs
    @partner_pairs ||= Commanders::PartnerPairs.call(mask: partner_target_mask)
  end

  # -> the selected mana as a ColorMask, 0 for colourless, nil when nothing is selected.
  def partner_target_mask
    letters = Array(params[:mana]).flat_map { |value| value.to_s.split(',') }.compact_blank
    return nil if letters.empty?
    return Commanders::ColorMask::COLORLESS if letters.include?('C')

    letters.uniq.sum { |letter| Commanders::ColorMask::BITS.fetch(letter, 0) }
  end

  def filter_by_boxset
    @cards.where(boxset_id: @boxset.id)
  end

  def filter_by_owned
    @cards.joins(collection_magic_cards: :collection)
          .where(collections: { user_id: current_user.id })
  end

  # Partner mode has already applied the colours - to the pair, by identity - so the per-card colour
  # filter would only throw away the halves it found.
  def filter_cards
    CollectionQuery::Filter.call(cards: @cards, params: partner_mode? ? params.except(:mana) : params)
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
