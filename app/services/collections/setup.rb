module Collections
  class Setup < Service
    def initialize(user:, current_user:, collection_id: nil, collection_type: nil, use_deck_scope: false)
      @user = user
      @current_user = current_user
      @collection_id = collection_id
      @collection_type = collection_type
      @use_deck_scope = use_deck_scope
    end

    def call
      {
        collection: find_collection,
        collections: ordered_collections,
        collections_value: user_collections.sum(:total_value),
        collection_history: build_collection_history
      }
    end

    private

    def find_collection
      Collection.find(@collection_id) if @collection_id.present?
    end

    def user_collections
      @user_collections ||= fetch_user_collections
    end

    def fetch_user_collections
      return @user.collections.decks if @use_deck_scope

      @collection_type ? @user.collections.by_type(@collection_type) : @user.collections
    end

    def ordered_collections
      return user_collections.order(:id).to_a unless owner?

      filter_ordered(@current_user.ordered_collections)
    end

    def owner?
      @current_user&.id == @user.id
    end

    def filter_ordered(ordered)
      return ordered.select { |c| Collection.deck_type?(c.collection_type) } if @use_deck_scope

      @collection_type ? ordered.select { |c| c.collection_type == @collection_type } : ordered
    end

    def build_collection_history
      collection = find_collection
      return collection.collection_history || {} if collection.present?

      Collection.aggregate_history(user_collections)
    end
  end
end
