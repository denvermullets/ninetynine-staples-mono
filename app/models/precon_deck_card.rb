class PreconDeckCard < ApplicationRecord
  BOARD_TYPES = %w[mainBoard sideBoard commander tokens].freeze
  # the boards a Commander game plays, mtgjson's camelCase name => the lowercase one collection_magic_cards
  # (and the API) use. The sideboard plays no part in Commander and tokens aren't a board of the deck
  API_BOARDS = { 'commander' => 'commander', 'mainBoard' => 'mainboard' }.freeze

  belongs_to :precon_deck
  belongs_to :magic_card

  validates :board_type, presence: true, inclusion: { in: BOARD_TYPES }
  validates :quantity, numericality: { greater_than: 0 }

  scope :by_board, ->(board) { where(board_type: board) }
  scope :commanders, -> { where(board_type: 'commander') }
  scope :main_board, -> { where(board_type: 'mainBoard') }
  scope :side_board, -> { where(board_type: 'sideBoard') }
  scope :tokens, -> { where(board_type: 'tokens') }
  scope :playable, -> { where(board_type: API_BOARDS.keys) }

  # { precon_deck_id => card count } for the given decks: commander and main board only
  def self.card_counts(precon_deck_ids)
    playable.where(precon_deck_id: precon_deck_ids).group(:precon_deck_id).sum(:quantity)
  end

  # Price for the finish this card is printed in, falling back to whatever
  # price data exists when the matching finish has none
  def unit_price
    price = is_foil ? magic_card.foil_price : magic_card.normal_price
    price.to_f.positive? ? price.to_f : magic_card.display_price.to_f
  end

  def value
    quantity * unit_price
  end
end
