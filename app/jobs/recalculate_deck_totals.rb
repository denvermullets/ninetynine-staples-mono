# Rebuilds every deck's cached total_* columns from its cards, for decks whose overview count drifted
# from the deck page
class RecalculateDeckTotals < ApplicationJob
  queue_as :collection_updates

  def perform
    Collection.decks.find_each { |deck| Collections::UpdateTotals.call(collection: deck) }
  end
end
