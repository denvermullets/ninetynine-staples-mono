module Collections
  class VisualModeSetup < Service
    def initialize(cards:, user:, grouping: 'none')
      @cards = cards
      @user = user
      @grouping = grouping
    end

    def call
      {
        aggregated_quantities: aggregate_quantities,
        grouped_cards: group_cards
      }
    end

    private

    def aggregate_quantities
      Collections::AggregateQuantities.call(magic_cards: @cards, user: @user)
    end

    def group_cards
      return nil if @grouping == 'none'

      Collections::GroupCards.call(cards: @cards, grouping: @grouping)
    end
  end
end
