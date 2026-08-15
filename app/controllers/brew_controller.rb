# "What weird deck could I build today with zero purchases?" - commanders ranked by how well the
# collection already supports them.
#
# Not authenticated, same as the stats dashboard, the set page and the proxies page: Scope decides
# which of the named user's collections the viewer is allowed to see, and a public one is readable
# logged out. current_user is who is looking, never whose cards are being counted.
#
# The list lives in a turbo frame with turbo_action advance, so the filter links and the pagination
# inside it swap the grid and move the URL without a stimulus controller or a turbo_stream endpoint
# of their own.
class BrewController < ApplicationController
  PER_PAGE = 50

  # The completeness floor, as pill labels. A floor rather than a band because the question is always
  # "at least this buildable" - nobody wants the commanders they can only half build.
  FLOORS = { 'all' => 0.0, 'half' => 0.5, 'most' => 0.75 }.freeze

  def index
    @scope = CollectionStats::Scope.call(username: params[:username], viewer: current_user,
                                         collection_id: params[:collection_id])
    return bounce_to_whole_collection if @scope[:missing]

    read_view_options
    load_commanders unless @scope[:collection_ids].empty?
  end

  private

  # Dropping the collection_id rather than keeping it, or the redirect would loop
  def bounce_to_whole_collection
    redirect_to collection_brew_path(params[:username]), alert: 'Collection not found'
  end

  def read_view_options
    @sort = requested(params[:sort], Commanders::Discovery::SORTS, 'buildable')
    @band = requested(params[:band], Commanders::Discovery::RANK_BANDS.keys, 'all')
    @floor = requested(params[:floor], FLOORS.keys, 'all')
    @owned_only = params[:owned_only] == 'true'
  end

  def requested(value, allowed, fallback)
    allowed.include?(value) ? value : fallback
  end

  def load_commanders
    result = Commanders::Discovery.call(
      collection_ids: @scope[:collection_ids], sort: @sort, band: @band,
      owned_only: @owned_only, min_completeness: FLOORS.fetch(@floor)
    )

    @total = result[:total]
    @matched = result[:matched]
    @pagy, @rows = pagy(:offset, result[:rows], limit: PER_PAGE)
    @cards = load_cards
  end

  # AFTER PAGY, NEVER PER ROW IN THE VIEW. Discovery scores every commander in the format as plain
  # tuples; hydrating all 3,235 into MagicCard records with their boxsets to display 50 of them would
  # be most of the request, and there is no production cache store to hide it behind.
  # Same shape as CardAnalysis::CommanderSynergy#load_cards.
  def load_cards
    MagicCard.where(id: @rows.pluck(:magic_card_id)).includes(:boxset).index_by(&:id)
  end
end
