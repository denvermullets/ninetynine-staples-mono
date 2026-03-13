class ComboCard < ApplicationRecord
  belongs_to :combo

  validates :card_name, :oracle_id, presence: true
end
