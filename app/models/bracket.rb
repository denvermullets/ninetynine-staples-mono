class Bracket < ApplicationRecord
  has_many :deck_rules, dependent: :destroy

  validates :level, presence: true, uniqueness: true,
                    numericality: { only_integer: true, greater_than: 0 }
  validates :name, presence: true

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:level) }
end
