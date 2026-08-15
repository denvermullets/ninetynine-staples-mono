# The two ways to find a card to add to a deck: search for one you have in mind, or be shown ones you
# have not. Both render a bare partial into the sidebar panel - no layout, no turbo stream.
module DeckBuilderSearchPanel
  extend ActiveSupport::Concern

  SEARCH_RESULT_LIMIT = 20
  SUGGESTIONS_PER_BUCKET = 12

  included do
    helper_method :deck_has_commander?
  end

  def search
    @results = DeckBuilder::Search.call(
      query: params[:q], user: current_user, deck: @deck,
      scope: params[:scope] || 'all', limit: SEARCH_RESULT_LIMIT
    )
    render partial: 'search_results', locals: { results: @results, deck: @deck }
  end

  # Owner-only for free: ensure_owner covers everything not named in its except: list, and the panel
  # this renders into only exists for the owner anyway.
  def suggestions
    commander = @deck.commanders.first&.magic_card

    result = commander && CardAnalysis::CommanderSynergy.call(
      commander: commander, user: current_user, deck: @deck,
      role: params[:role], owned_only: false, limit: SUGGESTIONS_PER_BUCKET
    )

    render partial: 'suggestions', locals: { result: result, deck: @deck, role: params[:role] }
  end

  # There is nothing to derive suggestions from without a commander, so the tab is not offered.
  def deck_has_commander?
    @deck.commanders.exists?
  end
end
