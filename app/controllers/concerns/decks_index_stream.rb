# Edit and delete modals opened from the decks index carry the page's sort and grouping (from=decks),
# so the response can redraw the grid the user is looking at instead of the deck builder's elements.
module DecksIndexStream
  extend ActiveSupport::Concern

  private

  def from_decks_index? = params[:from] == 'decks'

  # passed through to the modal's form so the submit comes back with the same view state
  def decks_index_params
    return {} unless from_decks_index?

    params.slice(:from, :sort, :group_by).permit(:from, :sort, :group_by).to_h.symbolize_keys
  end

  def decks_index_stream(user, exclude_id: nil)
    listing = Decks::Listing.call(
      user: user, viewer: current_user, sort: params[:sort], group_by: params[:group_by], exclude_id: exclude_id
    )
    turbo_stream.replace('deck_groups', partial: 'decks/deck_groups', locals: { listing: listing })
  end

  # the job removes the rows later; hide the collection now so the page doesn't wait on it.
  # remove_all because a deck with two tags sits under both tag groups
  def destroyed_collection_stream(collection)
    return decks_index_stream(collection.user, exclude_id: collection.id) if from_decks_index?

    turbo_stream.remove_all("#collection_card_#{collection.id}")
  end
end
