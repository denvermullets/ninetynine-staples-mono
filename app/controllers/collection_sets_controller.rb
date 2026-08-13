# One set, measured against one collection - the page the completion panel's rows link into.
#
# Not authenticated, same as the stats dashboard: Scope decides which of the named user's collections
# the viewer is allowed to see, and a public one is readable logged out. current_user is who is
# looking, never whose cards are being counted.
#
# Everything below the header lives in a turbo frame with turbo_action advance, so the owned/missing
# toggle and the pagination links inside it swap the table and move the URL without a stimulus
# controller or a turbo_stream endpoint of their own. The cost is that SetDetail's two aggregates
# re-run on a toggle, which is fine - they are bounded by one set.
class CollectionSetsController < ApplicationController
  PER_PAGE = 50

  VIEWS = %w[table visual].freeze

  def show
    @boxset = Boxset.find_by(code: params[:code])
    return head :not_found if @boxset.nil?

    @scope = CollectionStats::Scope.call(username: params[:username], viewer: current_user,
                                         collection_id: params[:collection_id])
    return bounce_to_whole_collection if @scope[:missing]

    read_view_options
    load_set unless @scope[:collection_ids].empty?
  end

  private

  # Dropping the collection_id rather than keeping it, or the redirect would loop
  def bounce_to_whole_collection
    redirect_to collection_set_path(params[:username], @boxset.code),
                alert: 'Collection not found'
  end

  def read_view_options
    @filter = requested_filter
    @view = VIEWS.include?(params[:view]) ? params[:view] : 'table'
  end

  def requested_filter
    return params[:filter] if CollectionStats::SetCards::FILTERS.include?(params[:filter])

    'all'
  end

  def load_set
    ids = @scope[:collection_ids]

    @sets = CollectionStats::OwnedSets.call(collection_ids: ids)
    @stats = CollectionStats::SetDetail.call(collection_ids: ids, boxset: @boxset)
    cards = CollectionStats::SetCards.call(collection_ids: ids, boxset: @boxset,
                                           filter: @filter, unit: unit)
    @counts = cards[:counts]
    @pagy, @rows = pagy(:offset, cards[:rows], limit: PER_PAGE)
    @labels = CollectionStats::PrintingLabels.call(magic_card_ids: page_printing_ids)
  end

  # The grid is a wall of art, so it is printings; the table is a list of cards you either have or
  # do not, so it is cards and the printings live inside the row
  def unit
    @view == 'visual' ? 'printing' : 'card'
  end

  # Labels are looked up for the printings actually on screen, which is why this runs after pagy
  # rather than inside SetCards - a set is a few hundred printings and a page is fifty
  def page_printing_ids
    return @rows.map { |row| row[:id] } if @view == 'visual'

    @rows.flat_map { |row| row[:printings].map { |printing| printing[:id] } }
  end
end
