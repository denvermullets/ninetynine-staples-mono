class DashboardController < ApplicationController
  def ingest
    IngestSets.perform_later

    redirect_to '/jobs'
  end

  def ingest_prices
    IngestPrices.perform_later

    redirect_to '/jobs'
  end
end
