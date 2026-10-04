# A preconstructed deck with its whole decklist, in the same shape as a user deck so the client loads an
# opponent's precon exactly like one of its own decks. Only the commander and main board come out,
# lowercased, and the deck's tokens go in `tokens` - the token definitions the engine can create for
# this deck - instead of on a board. The sideboard plays no part in Commander, so it is left out.
class Api::V1::PreconDeckSerializer
  def initialize(deck, rulings: false)
    @deck = deck
    @rulings = rulings
  end

  def as_json(*)
    rows = @deck.precon_deck_cards.where(board_type: [*PreconDeckCard::API_BOARDS.keys, 'tokens'])
                .includes(:magic_card).order(:id).to_a
    token_rows, deck_rows = split_tokens(rows)
    cards = card_payloads(rows.map(&:magic_card))

    {
      deck: Api::V1::PreconDeckSummarySerializer.many([@deck]).first,
      cards: deck_rows.map { |row| { board: board(row), quantity: row.quantity, card: cards[row.magic_card_id] } },
      tokens: token_rows.map { |row| cards[row.magic_card_id] }
    }
  end

  private

  # -> [token rows, deck rows], the deck rows commander first, then in the order they were ingested
  def split_tokens(rows)
    token_rows, deck_rows = rows.partition { |row| row.board_type == 'tokens' }
    [token_rows, deck_rows.sort_by.with_index { |row, index| [board_rank(row), index] }]
  end

  def board(row)
    PreconDeckCard::API_BOARDS.fetch(row.board_type)
  end

  def board_rank(row)
    PreconDeckCard::API_BOARDS.keys.index(row.board_type)
  end

  # { magic_card_id => card JSON }, each printing serialized once even when it is also a token
  def card_payloads(cards)
    cards = cards.uniq
    cards.map(&:id).zip(Api::V1::CardSerializer.many(cards, rulings: @rulings)).to_h
  end
end
