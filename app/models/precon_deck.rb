class PreconDeck < ApplicationRecord
  has_many :precon_deck_cards, dependent: :destroy
  has_many :magic_cards, through: :precon_deck_cards

  validates :code, :file_name, :name, presence: true
  validates :file_name, uniqueness: true

  scope :ingested, -> { where(cards_ingested: true) }
  scope :by_type, ->(type) { where(deck_type: type) if type.present? }
end
