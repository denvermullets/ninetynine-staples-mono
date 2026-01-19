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

  def backfill_boxset_history
    BackfillBoxsetValueHistory.perform_later

    redirect_to '/jobs'
  end

  def trim_boxset_history
    TrimBoxsetValueHistory.perform_later

    redirect_to '/jobs'
  end

  def backfill_price_change_weekly
    BackfillPriceChangeWeekly.perform_later

    redirect_to '/jobs'
  end

  def backfill_scryfall_oracle_id
    BackfillScryfallOracleId.perform_later

    redirect_to '/jobs'
  end
end
