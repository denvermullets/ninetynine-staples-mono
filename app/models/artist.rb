class Artist < ApplicationRecord
  validates :name, uniqueness: { case_sensitive: false }

  has_many :magic_card_artists
  has_many :magic_cards, through: :magic_card_artists

  def self.find_or_create_by_name(name)
    where('LOWER(name) = LOWER(?)', name).first || create!(name: name)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    where('LOWER(name) = LOWER(?)', name).first!
  end
end
