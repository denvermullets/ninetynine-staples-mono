class BulkEditsController < ApplicationController
  ROW_KEYS = %i[magic_card_id card_uuid from_collection_id to_collection_id
                quantity foil_quantity proxy_quantity proxy_foil_quantity].freeze

  before_action :authenticate_user!

  def index
    setup_index_defaults
    load_boxset_for_index
  end

  def load_table
    return handle_empty_params if params[:code].blank? && params[:search].blank?

    @collections = current_user.ordered_collections
    @boxset = determine_boxset
    load_cards

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end

  def save
    rows = parsed_rows
    @result = CollectionRecord::BulkApply.call(rows: rows, user: current_user)

    respond_to(&:turbo_stream)
  end

  private

  def setup_index_defaults
    @collections = current_user.ordered_collections
    @options = build_boxset_options
    @default_code = set_default_boxset
    @boxset = nil
    @magic_cards = []
    load_default_boxset if @default_code.present?
  end

  def load_boxset_for_index
    return unless params[:code].present? || params[:search].present?

    @boxset = determine_boxset
    load_cards
  end

  def load_cards
    cards = search_magic_cards
    @magic_cards = cards.to_a
  end

  def search_magic_cards
    @cards = @boxset.present? ? @boxset.magic_cards : MagicCard.all
    @cards = CollectionQuery::Search.call(
      cards: @cards, search_term: params[:search], boxset_id: @boxset&.id, collection_id: nil
    )
    @cards = @cards.where("card_side IS NULL OR card_side != 'b'")
    @cards = filter_by_price if params[:valuable_only] == 'true'
    @cards = CollectionQuery::Filter.call(cards: @cards, params: params)
    CollectionQuery::Sort.call(cards: @cards, sort_by: :id)
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
    load_cards if @boxset.present?
  end

  def determine_boxset
    return nil if params[:code] == 'all'

    fetch_boxset(params[:code])
  end

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end

  def handle_empty_params
    respond_to do |format|
      format.turbo_stream { head :no_content }
      format.html { redirect_to bulk_edit_path }
    end
  end

  def parsed_rows
    raw = params[:rows]
    return [] unless raw.is_a?(ActionController::Parameters) || raw.is_a?(Array)

    raw.map do |row|
      row = row.respond_to?(:permit) ? row.permit(ROW_KEYS).to_h : row.slice(*ROW_KEYS.map(&:to_s))
      row.with_indifferent_access
    end
  end
end
