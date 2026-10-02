# Builds the locals for shared/cards/_mobile_locations: the signed-in viewer's own copies of a card, so it
# reads the same on anyone's collection or a set page. Loaded lazily when a mobile card expands, and
# re-rendered after a transfer/adjust/trade submitted from inside it.
module MobileCardLocations
  extend ActiveSupport::Concern

  private

  def mobile_locations_locals(card)
    {
      magic_card: card,
      card_locations: card.collection_magic_cards.joins(:collection)
                          .where(collections: { user_id: current_user.id })
                          .preload(:collection).order('collections.name'),
      other_printing_locations: card.other_printing_locations(current_user),
      collections: current_user.ordered_collections
    }
  end

  # forms inside the mobile frame send its id as the Turbo-Frame header
  def mobile_frame_request?
    turbo_frame_request_id.to_s.start_with?('mobile_locations_')
  end
end
