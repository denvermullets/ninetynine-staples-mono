class DashboardController < ApplicationController
  def ingest
    IngestSets.perform_later

    redirect_to '/jobs'
  end

  def ingest_prices
    IngestPrices.perform_later

    redirect_to '/jobs'
  end

  def reset_collections
    ResetCollectionValues.perform_later

    redirect_to '/jobs'
  end

  def clear_jobs
    SolidQueue::Job.clear_finished_in_batches

    redirect_to '/jobs'
  end
end
