class DashboardController < ApplicationController
  def index
    @options = Boxset.where(valid_cards: true).map { |boxset| { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase } }
    render :index
  end

  def load_boxset
    @boxset = Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: params[:code])
    # some sets have non integer based card numbers, those i care less about sorting right now
    @magic_cards = @boxset.magic_cards.sort_by do |card|
      begin
        # Try to convert the card_number to an integer
        # trying to use a Tuple
        [ Integer(card.card_number), 0 ]
      rescue ArgumentError, TypeError
        # If it fails, place it at the end
        [ Float::INFINITY, 1 ]
      end
    end


    respond_to do |format|
      format.turbo_stream
    end
  end

  def ingest
    IngestSets.perform_later

    redirect_to "/jobs"
  end
end
