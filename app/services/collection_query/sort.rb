#
# handles sorting on a collection
#
module CollectionQuery
  class Sort < Service
    # card_number is a string ("12a", "T5", "W17-9"), so only cast the purely numeric ones and let
    # the rest fall to the end. The CASE/regex guard matches the Integer() semantics this sort used
    # to have in Ruby: Integer("12a") raises, so "12a" belongs in the NULLS LAST bucket. That makes
    # it deliberately stricter than CollectionQuery::CollectionSort::CARD_NUMBER_SQL, which strips
    # non-digits and would sort "12a" as 12.
    CARD_NUMBER_SQL = "CASE WHEN magic_cards.card_number ~ '^\\d+$' THEN magic_cards.card_number::bigint END".freeze

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

    # an ORDER BY rather than Enumerable#sort_by so the sort composes with the caller's LIMIT/OFFSET.
    # sorting in Ruby materialized every matching row before pagination could run - 1.5 s and 107k
    # instantiated records to render one 50-card page of "All Cards".
    #
    # card_number is not unique (2.5k values repeat across boxsets), so id is the final tiebreak:
    # without a total order the same card can show up on two pages while another is skipped, since
    # each page is a separate query that sorts from scratch.
    def sort_by_card_num(cards)
      cards
        .reorder(Arel.sql("#{CARD_NUMBER_SQL} ASC NULLS LAST"))
        .order('magic_cards.card_number' => :asc, 'magic_cards.id' => :asc)
    end
  end
end
