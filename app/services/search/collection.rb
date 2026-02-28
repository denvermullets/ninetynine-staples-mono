# Filters and sorts a card relation for the collections view.
# Called on every page load (not just searches) — sort_by: :price is the default.
# The first branch in handle_search drops user scoping intentionally
# for the boxsets view, where cards aren't scoped to a user.

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

    # Alias must be "computed_total_value" not "total_value" because collections.total_value exists on
    # the joined collections table and Postgres resolves the column name to that instead of the alias.
    # ORDER BY uses the full SUM() expression instead of the alias because
    # Pagy's count query rewrites SELECT to COUNT(*), stripping aliases.
    VALUE_SQL = <<~SQL.squish.freeze
      COALESCE(collection_magic_cards.quantity, 0) * COALESCE(magic_cards.normal_price, 0) +
      COALESCE(collection_magic_cards.foil_quantity, 0) * COALESCE(magic_cards.foil_price, 0)
    SQL

    ORDER_SQL = Arel.sql("SUM(#{VALUE_SQL}) DESC").freeze

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
        # A card can exist in multiple collections so we SUM quantities
        # across all collection_magic_cards rows to get the true totals.
        # The view uses quantity/foil_quantity to decide which price columns to show.
        @cards
          .joins(:collection_magic_cards)
          .select(
            "magic_cards.*,
             SUM(COALESCE(collection_magic_cards.quantity, 0)) AS quantity,
             SUM(COALESCE(collection_magic_cards.foil_quantity, 0)) AS foil_quantity,
             SUM(#{VALUE_SQL}) AS computed_total_value"
          )
          .group('magic_cards.id')
          .order(ORDER_SQL)
      end
    end
  end
end
