#
# handles sorting on a collection
#
module CollectionQuery
  class Sort < Service
    def initialize(cards:, sort_by:)
      @cards = cards
      @sort_by = sort_by
    end

    def call
      case @sort_by
      when :id
        sort_by_card_num(@cards)
      when :price
        @cards
          .joins(:collection_magic_cards)
          .select("magic_cards.*,
                  COALESCE(collection_magic_cards.quantity, 0) * COALESCE(magic_cards.normal_price, 0) +
                  COALESCE(collection_magic_cards.foil_quantity, 0) * COALESCE(magic_cards.foil_price, 0)
                  AS total_value")
          .order('total_value DESC')
      else
        @cards
      end
    end

    private

    def sort_by_card_num(cards)
      cards.sort_by do |card|
        [Integer(card.card_number), 0]
      rescue ArgumentError, TypeError
        [Float::INFINITY, 1]
      end
    end
  end
end
