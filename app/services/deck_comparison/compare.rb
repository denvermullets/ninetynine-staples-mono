# The diff between two comparison sides (DeckComparison::LoadSide hashes): which cards are in both
# decks, and which are in only one.
#
# It is presence-based. These are Commander decks, so a card is either in a deck or it is not; when
# both hold it in different numbers - basic lands - it is still Shared, and the row carries both counts
# rather than splitting copies across tabs.
#
# Sides are matched on the key LoadSide gave each card (the oracle id), all in Ruby: nothing here is
# persisted, so there is nothing to join. A shared card is drawn with a real deck's printing over a
# paste's generic one, and with A's when the sides are the same kind. It is a commander if either deck
# says so.
module DeckComparison
  class Compare < Service
    def initialize(side_a:, side_b:)
      @side_a = side_a
      @side_b = side_b
      @cards_a = side_a[:cards].index_by { |card| card[:key] }
      @cards_b = side_b[:cards].index_by { |card| card[:key] }
    end

    def call
      tabs = { shared: shared_rows,
               only_a: only_rows(@cards_a, @cards_b, :a),
               only_b: only_rows(@cards_b, @cards_a, :b) }

      { tabs: tabs, stats: tabs.transform_values { |rows| stats(rows) } }
    end

    private

    def shared_rows
      @cards_a.slice(*@cards_b.keys).map do |key, card_a|
        card_b = @cards_b[key]
        shown = prefer_b? ? card_b : card_a

        Row.new(magic_card: shown[:magic_card], board_type: shared_board_type(card_a, card_b),
                quantity_a: card_a[:quantity], quantity_b: card_b[:quantity], unit_price: shown[:unit_price])
      end
    end

    def only_rows(cards, other_cards, side)
      cards.except(*other_cards.keys).values.map do |card|
        Row.new(magic_card: card[:magic_card], board_type: card[:board_type], unit_price: card[:unit_price],
                quantity_a: (card[:quantity] if side == :a), quantity_b: (card[:quantity] if side == :b))
      end
    end

    # B's printing only wins when B is a real deck and A is not
    def prefer_b?
      @side_a[:source] != 'deck' && @side_b[:source] == 'deck'
    end

    def shared_board_type(card_a, card_b)
      [card_a, card_b].any? { |card| card[:board_type] == 'commander' } ? 'commander' : card_a[:board_type]
    end

    # `cards` is distinct cards, `quantity` copies - they part ways on basic lands. The label is the
    # copy count the page shows: "44 / 22" when the decks hold the shared cards in different numbers
    def stats(rows)
      { cards: rows.size, quantity: rows.sum(&:quantity), quantity_label: quantity_label(rows),
        value: rows.sum(&:value) }
    end

    def quantity_label(rows)
      totals = [rows.sum { |row| row.quantity_a.to_i }, rows.sum { |row| row.quantity_b.to_i }]
      totals.reject(&:zero?).uniq.join(' / ').presence || '0'
    end
  end
end
