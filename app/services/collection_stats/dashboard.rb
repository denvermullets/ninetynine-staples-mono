# Composes the whole analytics dashboard: resolve the scope, then build every panel from it.
#
# The controller gets one call and one hash. Panels are added here rather than as another line
# in the controller action, so growing the dashboard never touches a controller again.
module CollectionStats
  class Dashboard < Service
    def initialize(username:, viewer: nil, collection_id: nil)
      @username = username
      @viewer = viewer
      @collection_id = collection_id
    end

    def call
      return scope if scope[:missing] || scope[:collection_ids].empty?

      scope.merge(panels)
    end

    private

    def scope
      @scope ||= Scope.call(username: @username, viewer: @viewer, collection_id: @collection_id)
    end

    def panels
      ids = scope[:collection_ids]

      {
        overview: Overview.call(collection_ids: ids),
        rarity: Rarity.call(collection_ids: ids),
        price_tiers: PriceTiers.call(collection_ids: ids),
        card_types: CardTypes.call(collection_ids: ids),
        colors: Colors.call(collection_ids: ids),
        mana_curve: ManaCurve.call(collection_ids: ids),
        sets: Sets.call(collection_ids: ids)
      }
    end
  end
end
