class Combo < ApplicationRecord
  has_many :combo_cards, dependent: :destroy
  has_many :deck_combos, dependent: :destroy

  validates :spellbook_id, presence: true, uniqueness: true
end
