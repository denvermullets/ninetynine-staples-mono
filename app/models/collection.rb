class Collection < ApplicationRecord
  validates :name, :description, presence: true

  belongs_to :user

  has_many :collection_magic_cards
  has_many :magic_cards, through: :collection_magic_cards
  has_many :sourced_deck_cards, class_name: 'CollectionMagicCard', foreign_key: :source_collection_id

  scope :by_user, ->(id) { where(user_id: id) }
  scope :by_type, ->(type) { where(collection_type: type) }
  scope :decks, -> { where('collection_type = ? OR collection_type LIKE ?', 'deck', '%_deck') }

  def self.deck_type?(type)
    type == 'deck' || type&.end_with?('_deck')
  end

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

  # Build mode methods
  def deck?
    collection_type == 'deck'
  end

  def in_build_mode?
    collection_magic_cards.staged.exists?
  end

  def staged_cards_count
    collection_magic_cards.staged.sum(:staged_quantity) +
      collection_magic_cards.staged.sum(:staged_foil_quantity)
  end

  def needed_cards_count
    collection_magic_cards.needed.sum(:quantity) +
      collection_magic_cards.needed.sum(:foil_quantity)
  end

  def owned_cards_count
    total_quantity + total_foil_quantity
  end

  def commanders
    collection_magic_cards.commanders.includes(:magic_card)
  end

  def commander_deck?
    collection_type == 'commander_deck'
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
