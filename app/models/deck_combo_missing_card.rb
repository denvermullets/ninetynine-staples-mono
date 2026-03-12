class DeckComboMissingCard < ApplicationRecord
  belongs_to :deck_combo

  validates :card_name, presence: true
end
