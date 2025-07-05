#
# handles searching on a collection
#
module CollectionQuery
  class Search < Service
    def initialize(cards:, search_term:, boxset_id: nil, collection_id: nil)
      @cards = cards
      @search_term = search_term
      @boxset_id = boxset_id
      @collection_id = collection_id
    end

    def call
      return @cards unless @search_term.present?

      if @boxset_id.nil? && @collection_id.nil?
        MagicCard.where('name ILIKE ?', "%#{@search_term}%")
      elsif @boxset_id.present?
        @cards.where('magic_cards.name ILIKE ? AND magic_cards.boxset_id = ?', "%#{@search_term}%", @boxset_id)
      else
        @cards.where('magic_cards.name ILIKE ?', "%#{@search_term}%")
      end
    end
  end
end
