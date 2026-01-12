class CollectionMagicCard < ApplicationRecord
  belongs_to :collection
  belongs_to :magic_card
  belongs_to :source_collection, class_name: 'Collection', optional: true

  # Validations
  validates :quantity, :foil_quantity, :proxy_quantity, :proxy_foil_quantity,
            numericality: { greater_than_or_equal_to: 0 }
  validates :staged_quantity, :staged_foil_quantity,
            numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :with_proxies, -> { where('proxy_quantity > 0 OR proxy_foil_quantity > 0') }
  scope :real_only, -> { where(proxy_quantity: 0, proxy_foil_quantity: 0) }

  # Build mode scopes
  scope :staged, -> { where(staged: true) }
  scope :finalized, -> { where(staged: false) }
  scope :needed, -> { where(needed: true) }
  scope :owned, -> { where(needed: false) }
  scope :from_collection, -> { where.not(source_collection_id: nil) }
  scope :planned, -> { staged.where(source_collection_id: nil) }

  # Helper methods
  def total_regular
    quantity + proxy_quantity
  end

  def total_foil
    foil_quantity + proxy_foil_quantity
  end

  def proxies?
    proxy_quantity.positive? || proxy_foil_quantity.positive?
  end

  def real_value
    (quantity * magic_card.normal_price) + (foil_quantity * magic_card.foil_price)
  end

  def proxy_value
    (proxy_quantity * magic_card.normal_price) + (proxy_foil_quantity * magic_card.foil_price)
  end

  # Build mode methods
  def planned?
    staged? && source_collection_id.nil?
  end

  def from_owned_collection?
    staged? && source_collection_id.present?
  end

  def total_staged
    staged_quantity + staged_foil_quantity
  end

  def display_quantity
    staged? ? total_staged : (quantity + foil_quantity)
  end

  def available_swap?(user)
    needed? && magic_card.user_owned_copies(user).any?
  end
end
