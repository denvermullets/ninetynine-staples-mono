# Filters and sorts a card relation for the collections view.
# Called on every page load (not just searches) — sort_by: :price is the default.
# The first branch in handle_search drops user scoping intentionally
# for the boxsets view, where cards aren't scoped to a user.

module Search
  class Collection < Service
    # Highest price among the finishes the user actually owns. A printing owned only in
    # foil sorts on foil_price, and vice versa; a proxy-only row (no quantities) falls to 0.
    OWNED_PRICE_SQL = <<~SQL.squish.freeze
      GREATEST(
        CASE WHEN SUM(COALESCE(collection_magic_cards.quantity, 0)) > 0
             THEN COALESCE(magic_cards.normal_price, 0) ELSE 0 END,
        CASE WHEN SUM(COALESCE(collection_magic_cards.foil_quantity, 0)) > 0
             THEN COALESCE(magic_cards.foil_price, 0) ELSE 0 END
      )
    SQL

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
                 MagicCard.where('magic_cards.name ILIKE ?', "%#{@search_term}%")
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
        # A card can exist in multiple collections so we GROUP BY to deduplicate
        # and SUM quantities across all collection_magic_cards rows.
        # The view uses quantity/foil_quantity to decide which price columns to show,
        # so we sort by the highest price of the finishes actually owned - otherwise a
        # foil-only printing would be ranked by a normal_price that's never displayed.
        # CollectionQuery::CollectionSort reorders this relation when the user picks a column.
        @cards
          .joins(:collection_magic_cards)
          .select(
            "magic_cards.*,
             SUM(COALESCE(collection_magic_cards.quantity, 0)) AS quantity,
             SUM(COALESCE(collection_magic_cards.foil_quantity, 0)) AS foil_quantity"
          )
          .group('magic_cards.id')
          .order(Arel.sql("#{OWNED_PRICE_SQL} DESC NULLS LAST"))
      else
        @cards
      end
    end
  end
end
