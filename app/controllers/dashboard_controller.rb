class DashboardController < ApplicationController
  def index
    render :index
  end

  def ingest
    IngestSets.perform_later

    redirect_to "/jobs"
  end
end
