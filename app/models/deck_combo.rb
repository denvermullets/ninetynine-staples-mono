class DeckCombo < ApplicationRecord
  belongs_to :collection
  belongs_to :combo
  has_many :deck_combo_missing_cards, dependent: :destroy

  validates :combo_type, inclusion: { in: %w[included almost_included] }

  scope :included_combos, -> { where(combo_type: 'included') }
  scope :almost_included, -> { where(combo_type: 'almost_included') }
end
