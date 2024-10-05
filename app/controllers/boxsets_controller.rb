class BoxsetsController < ApplicationController
  def index
    @options = Boxset.all_sets.map { |boxset| { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase } }

    main_set = Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: params[:code])
    if main_set.present?
      boxset = sort_cards(main_set)
    end

    render :index, locals: { boxset: }
  end

  def load_boxset
    @boxset = Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: params[:code])
    # some sets have non integer based card numbers, those i care less about sorting right now
    @magic_cards = sort_cards(@boxset)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def sort_cards(collection)
    # takes in a boxset w/associated cards attached
    collection.magic_cards.sort_by do |card|
      begin
        # Try to convert the card_number to an integer
        # trying to use a Tuple
        [ Integer(card.card_number), 0 ]
      rescue ArgumentError, TypeError
        # If it fails, place it at the end
        [ Float::INFINITY, 1 ]
      end
    end
  end
end
