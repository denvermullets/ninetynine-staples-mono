class Collection < ApplicationRecord
  validates :name, :description, :collection_type, presence: true

  belongs_to :user

  has_many :collection_magic_cards
  has_many :magic_cards, through: :collection_magic_cards

  scope :by_user, ->(id) { where(user_id: id) }
end
