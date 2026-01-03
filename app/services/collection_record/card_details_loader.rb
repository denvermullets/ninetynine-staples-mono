# Shared logic for loading card details across user collections
module CollectionRecord
  module CardDetailsLoader
    private

    def reload_card_details(magic_card, collection)
      user = collection.user
      collections = user.collections
      card_locations = magic_card.collection_magic_cards.joins(:collection).where(collections: { user_id: user.id })
      editable = true

      { card: magic_card, collections: collections, card_locations: card_locations, editable: editable }
    end
  end
end
