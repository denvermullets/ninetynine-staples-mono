# Compares two decks without saving anything: the page's form holds both sides, and every submit -
# including each grouping, sort and view change - recomputes and swaps the results back in.
#
# Logged-in users only. Which deck a side may name is DeckComparison::LoadSide's rule - it looks the
# deck up among the viewer's own - so there is nothing more to authorize here.
class DeckComparisonsController < ApplicationController
  VIEW_MODES = %w[list card].freeze
  TABS = %w[shared only_a only_b].freeze

  before_action :authenticate_user!
  before_action :set_view_options

  def show
    @decks = current_user.collections.decks.order(:name).to_a
    # looked up among the viewer's own decks, so a foreign id is silently ignored
    @prefill_a = @decks.find { |deck| deck.id == params[:a].to_i }&.id
  end

  def create
    @sides = [load_side('a'), load_side('b')]
    compare if comparable?

    # the form may be submitted as plain HTML, so the format is named rather than negotiated
    render :create, formats: :turbo_stream
  end

  private

  def set_view_options
    @view_mode = VIEW_MODES.include?(params[:view_mode]) ? params[:view_mode] : 'list'
    @tab = TABS.include?(params[:tab]) ? params[:tab] : 'shared'
    @grouping = whitelisted(params[:grouping], DeckComparison::GroupCards::GROUPING_OPTIONS, 'type')
    @sort_by = whitelisted(params[:sort_by], DeckComparison::GroupCards::SORT_OPTIONS, 'mana_value')
  end

  def whitelisted(value, options, default)
    options.include?(value) ? value : default
  end

  def load_side(prefix)
    DeckComparison::LoadSide.call(viewer: current_user, source: params["#{prefix}_source"],
                                  text: params["#{prefix}_text"], deck_id: params["#{prefix}_deck_id"],
                                  label: prefix.upcase)
  end

  # one blank side still compares - everything lands in the other's tab - but an error or two blanks
  # leaves only a message to show
  def comparable?
    @sides.none? { |side| side[:error] } && !@sides.all? { |side| side[:blank] }
  end

  def compare
    @comparison = DeckComparison::Compare.call(side_a: @sides.first, side_b: @sides.last)
    @grouped = @comparison[:tabs].transform_values do |rows|
      DeckComparison::GroupCards.call(cards: rows, grouping: @grouping, sort_by: @sort_by)
    end
  end
end
