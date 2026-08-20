# The Reserved List, measured against everything this user owns.
#
# Deliberately NOT scoped to one collection, which is the one place this page departs from its
# siblings: "am I ever going to be able to build this deck" is a question about the whole shelf, and
# a Reserved List card sitting in a different binder is still a card you do not have to buy. So Scope
# is called with no collection_id and there is no picker.
#
# Not authenticated, same as the rest of the family: Scope decides which of the named user's
# collections the viewer is allowed to count, and a public one is readable logged out. current_user
# is who is looking, never whose cards are being counted.
class CollectionReservedController < ApplicationController
  # 60 rather than the sets pages' 50 so a page fills the 2/3/4/6-column grid exactly
  PER_PAGE = 60

  VIEWS = %w[table visual].freeze

  def show
    @scope = CollectionStats::Scope.call(username: params[:username], viewer: current_user)

    read_view_options
    load_cards unless @scope[:collection_ids].empty?
  end

  private

  def read_view_options
    @filter = requested(:filter, CollectionStats::ReservedCards::FILTERS, 'all')
    @sort = requested(:sort, CollectionStats::ReservedCards::SORTS, 'name')
    @view = requested(:view, VIEWS, 'visual')
  end

  # The grid is a wall of art, so it is printings; the table is a list of cards you either have or do
  # not, so it is cards and the printings live inside the row. Same split the set page makes.
  def unit
    @view == 'visual' ? 'printing' : 'card'
  end

  def requested(param, allowed, fallback)
    allowed.include?(params[param]) ? params[param] : fallback
  end

  def load_cards
    cards = CollectionStats::ReservedCards.call(collection_ids: @scope[:collection_ids],
                                                filter: @filter, sort: @sort, unit: unit)

    @counts = cards[:counts]
    @totals = cards[:totals]
    @pagy, @rows = pagy(:offset, cards[:rows], limit: PER_PAGE)
    @labels = CollectionStats::PrintingLabels.call(magic_card_ids: page_printing_ids)
  end

  # Labels are looked up for the printings actually on screen, which is why this runs after pagy -
  # the list is a thousand-odd printings and a page is sixty. A card row carries its printings
  # inside it, so at table unit the ids are one level down.
  def page_printing_ids
    return @rows.map { |row| row[:id] } if @view == 'visual'

    @rows.flat_map { |row| row[:printings].map { |printing| printing[:id] } }
  end
end
