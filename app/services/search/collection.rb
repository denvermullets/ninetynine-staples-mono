# this service will take in a collection of cards
# searches and sorts the collection

module Search
  class Collection < Service
    def initialize(cards:, search_term:, sort_by:, code: nil, collection_id: nil)
      @cards = cards
      @search_term = search_term
      @boxset_id = code.nil? ? nil : Boxset.find_by(code: code)&.id
      @sort_by = sort_by
      @collection_id = collection_id
    end

    def call
      @cards = @cards.where(collections: { id: @collection_id }) if @collection_id.present?
      @cards = @cards.where('boxset_id = ?', @boxset_id) if @boxset_id.present?
      @cards = handle_search
      @cards = sort_cards

      @cards
    end

    private

    # i know this is not the most efficient but it's mainly boxsets (max 800 records?) that'll hit it
    def sort_by_card_num(cards)
      # takes in a collection of cards and sorts, card_number is not guaranteed to be an integer
      cards.sort_by do |card|
        # try to convert the card_number to an integer, trying to use a Tuple
        [Integer(card.card_number), 0]
      rescue ArgumentError, TypeError
        # if it fails, place it at the end
        [Float::INFINITY, 1]
      end
    end

    def handle_search
      @cards = if @search_term.present? && @boxset_id.nil? && @collection_id.nil?
                 MagicCard.where('name ILIKE ?', "%#{@search_term}%")
               elsif @search_term.present? && @boxset_id.present?
                 @cards.where('magic_cards.name ILIKE ? AND magic_cards.boxset_id = ?', "%#{@search_term}%", @boxset_id)
               else
                 @cards.where('magic_cards.name ILIKE ?', "%#{@search_term}%")
               end
    end

    def sort_cards
      case @sort_by
      when :id
        @cards = sort_by_card_num(@cards)
      when :price
        # TODO: when we add table sorting this will not work for boxsets
        @cards
          .joins(:collection_magic_cards)
          .select("magic_cards.*,
                  collection_magic_cards.foil_quantity,
                  collection_magic_cards.quantity,
                  COALESCE(collection_magic_cards.quantity, 0) * COALESCE(magic_cards.normal_price, 0) +
                  COALESCE(collection_magic_cards.foil_quantity, 0) * COALESCE(magic_cards.foil_price, 0)
                  AS total_value")
          .order('total_value DESC')
      end
    end
  end
end
