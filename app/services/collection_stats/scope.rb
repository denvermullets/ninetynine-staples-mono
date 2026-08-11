# Works out whose collections the analytics dashboard is allowed to report on.
#
# A service rather than a controller filter so the visibility rules can be tested directly:
# who can see which collections, and what happens when someone passes a collection id that is
# not theirs. That is the part worth having tests around, and it is awkward to reach through a
# before_action.
#
# Resolving down to a flat list of ids is the point. Every panel then filters on
# collection_magic_cards.collection_id directly, which hits
# index_collection_magic_cards_on_collection_id without dragging the collections table into a
# dozen separate aggregate queries.
module CollectionStats
  class Scope < Service
    def initialize(username:, viewer: nil, collection_id: nil)
      @username = username
      @viewer = viewer
      @collection_id = collection_id
    end

    def call
      return missing if requested_missing?

      {
        user: user,
        owner: owner?,
        collections: collections,
        collection: selected,
        collection_ids: selected ? [selected.id] : collections.map(&:id),
        history: history,
        missing: false
      }
    end

    private

    # find_by! so an unknown username 404s the same way the other collection pages do
    def user
      @user ||= User.find_by!(username: @username)
    end

    def owner?
      @viewer&.id == user.id
    end

    def collections
      @collections ||= if owner?
                         user.ordered_collections.to_a
                       else
                         user.collections.includes(:cover_card).visible_to_public.order(:id).to_a
                       end
    end

    # Looked up through the collections already loaded for this user rather than
    # Collection.find_by(id:) - that is what stops one user's collection being reported on by
    # passing its id under somebody else's username. CollectionsController#enforce_visibility
    # uses a bare find_by and does not make this check.
    def selected
      return if @collection_id.blank?

      @selected ||= collections.find { |collection| collection.id == @collection_id.to_i }
    end

    def requested_missing?
      @collection_id.present? && selected.nil?
    end

    def missing
      { user: user, owner: owner?, collections: collections, collection: nil,
        collection_ids: [], history: {}, missing: true }
    end

    def history
      return selected.collection_history || {} if selected

      Collection.aggregate_history(collections)
    end
  end
end
