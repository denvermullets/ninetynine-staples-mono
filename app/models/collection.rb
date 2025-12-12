class Collection < ApplicationRecord
  validates :name, :description, presence: true

  belongs_to :user

  has_many :collection_magic_cards
  has_many :magic_cards, through: :collection_magic_cards

  scope :by_user, ->(id) { where(user_id: id) }
  scope :by_type, ->(type) { where(collection_type: type) }
end
