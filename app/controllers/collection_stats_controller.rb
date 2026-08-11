class CollectionStatsController < ApplicationController
  def show
    @stats = CollectionStats::Dashboard.call(
      username: params[:username], viewer: current_user, collection_id: params[:collection_id]
    )
    return unless @stats[:missing]

    redirect_to collections_stats_path(params[:username]), alert: 'Collection not found'
  end
end
