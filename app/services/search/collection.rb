# this service will take in a collection of cards
# searches and sorts the collection

module Search
  class Collection < Service
    def initialize(collection:, search_term:, code:)
      @collection = collection&.magic_cards || []
      @search_term = search_term
      @boxset_id = code.nil? ? nil : Boxset.find_by(code: code)&.id
    end

    def call
      return [] if @collection&.empty? && @search_term&.empty?

      sort_cards(query_cards)
    end

    private

    def query_cards
      if @collection.blank? && @search_term.present?
        # only on boxset view will this be hit, collections view currently always has a lookup first
        MagicCard.where('name ILIKE ?', "%#{@search_term}%")
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

    def sort_cards(cards)
      # takes in a collection of cards and sorts
      cards.sort_by do |card|
        # try to convert the card_number to an integer, trying to use a Tuple
        [Integer(card.card_number), 0]
      rescue ArgumentError, TypeError
        # if it fails, place it at the end
        [Float::INFINITY, 1]
      end
    end
  end
end
