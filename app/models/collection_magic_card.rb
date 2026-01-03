class CollectionMagicCard < ApplicationRecord
  belongs_to :collection
  belongs_to :magic_card

  # Validations
  validates :quantity, :foil_quantity, :proxy_quantity, :proxy_foil_quantity,
            numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :with_proxies, -> { where('proxy_quantity > 0 OR proxy_foil_quantity > 0') }
  scope :real_only, -> { where(proxy_quantity: 0, proxy_foil_quantity: 0) }

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
end
