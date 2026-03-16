class GameChanger < ApplicationRecord
  validates :oracle_id, presence: true, uniqueness: true
  validates :card_name, presence: true

  scope :alphabetical, -> { order(:card_name) }
  scope :for_cards, ->(oracle_ids) { where(oracle_id: oracle_ids) }
end
