class FrameEffect < ApplicationRecord
  validates :name, uniqueness: { case_sensitive: false }

  has_many :magic_card_frame_effects
  has_many :magic_cards, through: :magic_card_frame_effects
end
