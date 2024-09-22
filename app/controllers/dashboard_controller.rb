class DashboardController < ApplicationController
  def index
    @options = Boxset.where(valid_cards: true).map { |boxset| { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase } }
    render :index
  end

  # def index
  #   @options = YourModel.select(:id, :name, :code).map do |item|
  #     { id: item.id, name: item.name, code: item.code }
  #   end
  # end

  def load_boxset
    @boxset = Boxset.includes(magic_cards: { magic_card_color_idents: :color }).find_by(code: params[:code])

    respond_to do |format|
      format.turbo_stream
    end
  end

  def ingest
    IngestSets.perform_later

    redirect_to "/jobs"
  end
end
