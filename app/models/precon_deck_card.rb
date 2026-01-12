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
end
