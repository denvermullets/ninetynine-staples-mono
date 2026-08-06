class PreconDeckCard < ApplicationRecord
  BOARD_TYPES = %w[mainBoard sideBoard commander tokens].freeze

  belongs_to :precon_deck
  belongs_to :magic_card

  validates :board_type, presence: true, inclusion: { in: BOARD_TYPES }
  validates :quantity, numericality: { greater_than: 0 }

  scope :by_board, ->(board) { where(board_type: board) }
  scope :commanders, -> { where(board_type: 'commander') }
  scope :main_board, -> { where(board_type: 'mainBoard') }
  scope :side_board, -> { where(board_type: 'sideBoard') }
  scope :tokens, -> { where(board_type: 'tokens') }

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
