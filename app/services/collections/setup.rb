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
      base = owner? ? @user.collections : @user.collections.visible_to_public
      return base.decks if @use_deck_scope

      @collection_type ? base.by_type(@collection_type) : base
    end

    def ordered_collections
      unless owner?
        collections = user_collections.order(:id).to_a
        return collections.select(&:is_public)
      end

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
