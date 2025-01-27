class BoxsetsController < ApplicationController
  require 'pagy/extras/array'

  def index
    @options = Boxset.all_sets.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end

    # If a boset or search term is present, load the boxset
    load_boxset if params[:code].present? || params[:search].present?

    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def load_boxset
    @boxset = fetch_boxset(params[:code])
    magic_cards = Search::Collection.call(collection: @boxset, search_term: params[:search], code: params[:code])
    @pagy, @magic_cards = pagy_array(magic_cards)

    respond_to do |format|
      format.turbo_stream
      format.html { render 'index' }
    end
  end

  private

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end
end
