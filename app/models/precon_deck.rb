class PreconDeck < ApplicationRecord
  has_many :precon_deck_cards, dependent: :destroy
  has_many :magic_cards, through: :precon_deck_cards

  validates :code, :file_name, :name, presence: true
  validates :file_name, uniqueness: true

  scope :with_cards, -> { joins(:precon_deck_cards).distinct }
  scope :by_type, ->(type) { where(deck_type: type) if type.present? }

  def released?
    release_date.present? && release_date <= Date.current
  end

  def within_sync_window?
    return false unless released?

    release_date > 2.weeks.ago.to_date
  end

  def needs_card_sync?
    released? && within_sync_window?
  end
end
