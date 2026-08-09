module Collections
  class VisualModeSetup < Service
    # cards is the paginated page, already loaded - the caller must not hand this an unpaginated
    # relation, or aggregating the ids instantiates the user's entire collection
    def initialize(cards:, user:, grouping: 'none', collection_id: nil)
      @cards = cards
      @user = user
      @grouping = grouping
      @collection_id = collection_id
    end

    def call
      {
        aggregated_quantities: aggregate_quantities,
        grouped_cards: group_cards
      }
    end

    private

    def aggregate_quantities
      Collections::AggregateQuantities.call(magic_card_ids: @cards.map(&:id), user: @user,
                                            collection_id: @collection_id)
    end

    def group_cards
      return nil if @grouping == 'none'

      Collections::GroupCards.call(cards: @cards, grouping: @grouping)
    end
  end
end
