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
    magic_cards = filter_and_sort_cards(@boxset, params[:search])
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

  def filter_and_sort_cards(boxset, search_term)
    return [] if boxset.nil? && search_term.empty?

    if boxset.nil? && search_term.present?
      cards = MagicCard.where('name ILIKE ?', "%#{search_term}%")
    else
      cards = boxset.magic_cards
      cards = cards.where('name ILIKE ? AND boxset_id = ?', "%#{search_term}%", boxset.id) if search_term.present?
    end

    sort_cards(cards)
  end

  def sort_cards(cards)
    # takes in a boxset w/associated cards attached
    cards.sort_by do |card|
      # Try to convert the card_number to an integer
      # trying to use a Tuple
      [Integer(card.card_number), 0]
    rescue ArgumentError, TypeError
      # If it fails, place it at the end
      [Float::INFINITY, 1]
    end
  end
end
