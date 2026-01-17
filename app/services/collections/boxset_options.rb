module Collections
  class BoxsetOptions < Service
    def initialize(collections:, collection_id: nil)
      @collections = collections
      @collection_id = collection_id
    end

    def call
      boxset_ids = load_collection_boxset_ids
      Boxset.where(id: boxset_ids).map do |boxset|
        { id: boxset.id, name: boxset.name, code: boxset.code, keyrune_code: boxset.keyrune_code.downcase }
      end
    end

    private

    def load_collection_boxset_ids
      return all_collection_boxset_ids unless @collection_id.present?

      single_collection_boxset_ids
    end

    def single_collection_boxset_ids
      collection = @collections.find_by(id: @collection_id)
      return [] unless collection

      collection.magic_cards.pluck(:boxset_id).uniq.compact
    end

    def all_collection_boxset_ids
      @collections.flat_map { |col| col.magic_cards.pluck(:boxset_id) }.uniq.compact
    end
  end
end
