class Collection < ApplicationRecord
  validates :name, :description, presence: true

  belongs_to :user

  has_many :collection_magic_cards
  has_many :magic_cards, through: :collection_magic_cards

  scope :by_user, ->(id) { where(user_id: id) }
  scope :by_type, ->(type) { where(collection_type: type) }

  # Aggregate collection history across multiple collections
  # Returns a hash of date => total_value
  def self.aggregate_history(collections)
    aggregated = {}

    collections.each do |collection|
      next unless collection.collection_history.present?

      collection.collection_history.each do |date, value|
        aggregated[date] ||= 0.0
        aggregated[date] += value.to_f
      end
    end

    # Sort by date
    aggregated.sort.to_h
  end
end
