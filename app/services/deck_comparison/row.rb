# One line of a deck comparison: a card, and how many copies each deck holds.
#
# It stands in for the deck row the grouping service and the card partials were written against, which
# only ever ask a row for its board, its magic card and its price - so a comparison, which persists
# nothing, can be drawn by the same code as a real deck. A quantity is nil on the side that does not
# hold the card.
module DeckComparison
  Row = Data.define(:magic_card, :board_type, :quantity_a, :quantity_b, :unit_price) do
    def quantity = quantity_a || quantity_b
    def value = unit_price.to_f * quantity
    def both_sides? = !quantity_a.nil? && !quantity_b.nil?

    # "12 / 9" only when the decks disagree - in practice, basic lands
    def quantity_label
      both_sides? && quantity_a != quantity_b ? "#{quantity_a} / #{quantity_b}" : quantity.to_s
    end
  end
end
