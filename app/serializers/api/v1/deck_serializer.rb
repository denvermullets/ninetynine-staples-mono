# A deck with its whole decklist, as the client loads it to play. `deck` is the same summary the index
# returns; `cards` has one entry per card and board, so two rows of the same printing on one board (an
# owned copy beside a staged one) come out as one entry with their copies added up.
class Api::V1::DeckSerializer
  BOARD_ORDER = %w[commander mainboard sideboard].freeze

  def initialize(deck, rulings: false)
    @deck = deck
    @rulings = rulings
  end

  def as_json(*)
    entries = decklist_entries
    cards = card_payloads(entries.map(&:first))

    {
      deck: Api::V1::DeckSummarySerializer.many([@deck]).first,
      cards: entries.map { |card, board, quantity| { board: board, quantity: quantity, card: cards[card.id] } },
      # reserved for the tokens a deck makes; nothing fills it yet
      tokens: []
    }
  end

  private

  # [[MagicCard, board, quantity]], commander first, then in the order the rows were added
  def decklist_entries
    rows = @deck.collection_magic_cards.includes(:magic_card).order(:id)

    rows.group_by { |row| [row.magic_card_id, row.board_type || 'mainboard'] }
        .map { |(_, board), group| [group.first.magic_card, board, group.sum(&:decklist_quantity)] }
        .select { |_, _, quantity| quantity.positive? }
        .sort_by.with_index { |(_, board, _), index| [board_rank(board), index] }
  end

  def board_rank(board)
    BOARD_ORDER.index(board) || BOARD_ORDER.length
  end

  # { magic_card_id => card JSON }, each printing serialized once even when it sits on two boards
  def card_payloads(cards)
    cards = cards.uniq
    cards.map(&:id).zip(Api::V1::CardSerializer.many(cards, rulings: @rulings)).to_h
  end
end
