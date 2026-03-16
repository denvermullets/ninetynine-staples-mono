class DeckRule < ApplicationRecord
  RULE_TYPES = %w[max_game_changers max_copies_per_card max_deck_size].freeze
  APPLIES_TO_OPTIONS = %w[all commander_deck deck].freeze

  belongs_to :bracket, optional: true

  validates :name, presence: true
  validates :rule_type, presence: true, inclusion: { in: RULE_TYPES }
  validates :value, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :rule_type, uniqueness: { scope: %i[applies_to bracket_id] }
  validates :applies_to, presence: true, inclusion: { in: APPLIES_TO_OPTIONS }

  scope :enabled, -> { where(enabled: true) }
  scope :for_bracket, ->(bracket) { where(bracket: bracket) }
  scope :by_type, ->(type) { where(rule_type: type) }
  scope :global, -> { where(bracket_id: nil) }
  scope :applicable_to, ->(type) { where(applies_to: ['all', type]) }
end
