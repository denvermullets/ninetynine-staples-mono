# this service will take in a collection and sort it

module Search
  class Collection < Service
    def initialize(collection:, search_term:, code:)
      @collection = collection&.magic_cards || []
      @search_term = search_term
      @boxset_id = code.nil? ? nil : Boxset.find_by(code: code)&.id
    end

    def call
      return [] if @collection.empty? && @search_term.empty?

      query_cards
    end

    private

    def query_cards
      if @collection.blank? && @search_term.present?
        # not sure we'll hit this ever with this service
        # cards = MagicCard.where('name ILIKE ?', "%#{search_term}%")
      elsif search_empty && @boxset_id.present?
        @collection.where('boxset_id = ?', @boxset_id)
      elsif @search_term.present? && @boxset_id.present?
        @collection.where('name ILIKE ? AND boxset_id = ?', "%#{@search_term}%", @boxset_id)
      else
        @collection.where('name ILIKE ?', "%#{@search_term}%")
      end
    end

    def search_empty
      @search_term.nil? || @search_term.empty?
    end
  end
end
