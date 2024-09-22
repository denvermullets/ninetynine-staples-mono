class DashboardController < ApplicationController
  def index
    @options = Boxset.where(valid_cards: true).map { |boxset| { id: boxset.id, name: boxset.name, code: boxset.code } }
    render :index
  end

  # def index
  #   @options = YourModel.select(:id, :name, :code).map do |item|
  #     { id: item.id, name: item.name, code: item.code }
  #   end
  # end

  def load_boxset
    boxsets = Boxset.where(code: params[:code])
    @related_data = boxsets

    respond_to do |format|
      format.turbo_stream
    end
  end

  def ingest
    IngestSets.perform_later

    redirect_to "/jobs"
  end
end
