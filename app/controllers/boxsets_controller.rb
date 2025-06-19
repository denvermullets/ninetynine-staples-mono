class BoxsetsController < ApplicationController
  require 'pagy/extras/array'

  def index
    @options = Boxset.all_sets.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end

    # If a boxset or search term is present, load the boxset
    load_boxset if params[:code].present? || params[:search].present?

    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def load_boxset
    if params[:code].blank? && params[:search].blank?
      respond_to do |format|
        format.turbo_stream { head :no_content }
        format.html { redirect_to root_path }
      end
      return
    end

    @boxset = fetch_boxset(params[:code])
    @pagy, @magic_cards = pagy_array(search_magic_cards)

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  private

  def search_magic_cards
    @cards = @boxset&.magic_cards if @boxset.present?
    @cards = search_cards
    @cards = filter_cards
    CollectionQuery::Sort.call(cards: @cards, sort_by: :id)
  end

  def search_cards
    CollectionQuery::Search.call(
      cards: @cards, search_term: params[:search], boxset_id: @boxset&.id, collection_id: nil
    )
  end

  def filter_cards
    CollectionQuery::Filter.call(
      cards: @cards, code: nil, collection_id: nil, rarities: params[:rarity], colors: params[:mana]
    )
  end

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end
end
