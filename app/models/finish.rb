class Finish < ApplicationRecord
  validates :name, uniqueness: { case_sensitive: false }

  has_many :magic_card_finishes
  has_many :magic_cards, through: :magic_card_finishes
end
