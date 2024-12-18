class BoxsetsController < ApplicationController
  def index
    @options = Boxset.all_sets.map do |boxset|
      { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
    end

    # If params[:code] is present, load the boxset
    load_boxset if params[:code].present?

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def load_boxset
    @boxset = fetch_boxset(params[:code])
    @magic_cards = filter_and_sort_cards(@boxset, params[:search])

    return unless request.format.turbo_stream?

    respond_to(&:turbo_stream)
  end

  private

  def fetch_boxset(code)
    return if code.nil?

    Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: code)
  end

  def filter_and_sort_cards(boxset, search_term)
    return [] unless boxset

    cards = boxset.magic_cards
    cards = cards.where('name ILIKE ? AND boxset_id = ?', "%#{search_term}%", boxset.id) if search_term.present?

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
