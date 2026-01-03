class Collection < ApplicationRecord
  validates :name, :description, presence: true

  belongs_to :user

  has_many :collection_magic_cards
  has_many :magic_cards, through: :collection_magic_cards

  scope :by_user, ->(id) { where(user_id: id) }
  scope :by_type, ->(type) { where(collection_type: type) }

  # Helper methods for proxy tracking
  def total_estimated_value
    total_value + proxy_total_value
  end

  def total_cards
    total_quantity + total_foil_quantity + total_proxy_quantity + total_proxy_foil_quantity
  end

  def total_real_cards
    total_quantity + total_foil_quantity
  end

  def total_proxy_cards
    total_proxy_quantity + total_proxy_foil_quantity
  end

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
