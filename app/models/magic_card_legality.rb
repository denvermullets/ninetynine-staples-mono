class MagicCardLegality < ApplicationRecord
  belongs_to :magic_card
  belongs_to :legality

  validates :status, presence: true
  # Uniqueness handled by DB constraint to avoid race conditions

  scope :legal, -> { where(status: 'Legal') }
  scope :banned, -> { where(status: 'Banned') }
  scope :restricted, -> { where(status: 'Restricted') }
  scope :for_format, ->(format_name) { joins(:legality).where(legalities: { name: format_name }) }
end
