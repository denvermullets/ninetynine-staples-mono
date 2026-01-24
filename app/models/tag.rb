class Tag < ApplicationRecord
  validates :name, presence: true, uniqueness: true

  has_many :collection_tags, dependent: :destroy
  has_many :collections, through: :collection_tags

  scope :alphabetical, -> { order(:name) }
end
