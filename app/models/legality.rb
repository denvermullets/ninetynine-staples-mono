class Legality < ApplicationRecord
  has_many :magic_card_legalities, dependent: :destroy
  has_many :magic_cards, through: :magic_card_legalities

  validates :name, presence: true, uniqueness: true
end
