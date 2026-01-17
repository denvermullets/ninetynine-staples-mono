module DeckBuilder
  class LoadCards < Service
    def initialize(deck:, grouping:, sort_by:)
      @deck = deck
      @grouping = grouping
      @sort_by = sort_by
    end

    def call
      all_cards = @deck.collection_magic_cards
                       .includes(magic_card: %i[boxset sub_types colors magic_card_color_idents])

      staged = all_cards.staged
      needed = all_cards.needed
      owned = all_cards.finalized.owned
      cards_to_group = staged + needed + owned

      {
        staged_cards: staged,
        needed_cards: needed,
        owned_cards: owned,
        grouped_cards: GroupCards.call(cards: cards_to_group, grouping: @grouping, sort_by: @sort_by),
        stats: build_stats(cards_to_group, staged, needed, owned)
      }
    end

    private

    def build_stats(cards, staged, needed, owned)
      {
        total: cards.sum(&:display_quantity),
        staged: staged.sum(&:total_staged),
        needed: needed.sum { |c| c.quantity + c.foil_quantity },
        owned: owned.sum { |c| c.quantity + c.foil_quantity },
        value: calculate_deck_value(cards)
      }
    end

    def calculate_deck_value(cards)
      cards.sum(&:display_value)
    end
  end
end
