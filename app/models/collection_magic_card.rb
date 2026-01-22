class CollectionMagicCard < ApplicationRecord
  BOARD_TYPES = %w[mainboard sideboard commander].freeze

  belongs_to :collection
  belongs_to :magic_card
  belongs_to :source_collection, class_name: 'Collection', optional: true

  # Validations
  validates :quantity, :foil_quantity, :proxy_quantity, :proxy_foil_quantity,
            numericality: { greater_than_or_equal_to: 0 }
  validates :staged_quantity, :staged_foil_quantity, :staged_proxy_quantity, :staged_proxy_foil_quantity,
            numericality: { greater_than_or_equal_to: 0 }
  validates :board_type, inclusion: { in: BOARD_TYPES }, allow_nil: true

  # Scopes
  scope :with_proxies, -> { where('proxy_quantity > 0 OR proxy_foil_quantity > 0') }
  scope :real_only, -> { where(proxy_quantity: 0, proxy_foil_quantity: 0) }

  # Board type scopes
  scope :commanders, -> { where(board_type: 'commander') }
  scope :mainboard, -> { where(board_type: 'mainboard') }
  scope :sideboard, -> { where(board_type: 'sideboard') }

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

  # Display type detection (handles staged vs finalized cards)
  def display_foil?
    if staged?
      staged_foil_quantity.positive? || staged_proxy_foil_quantity.positive?
    else
      foil_quantity.positive? || proxy_foil_quantity.positive?
    end
  end

  def display_proxy?
    if staged?
      staged_proxy_quantity.positive? || staged_proxy_foil_quantity.positive?
    else
      proxy_quantity.positive? || proxy_foil_quantity.positive?
    end
  end

  def real_value
    (quantity * magic_card.normal_price) + (foil_quantity * magic_card.foil_price)
  end

  def proxy_value
    ((proxy_quantity || 0) * magic_card.normal_price.to_f) +
      ((proxy_foil_quantity || 0) * magic_card.foil_price.to_f)
  end

  # Value for deck builder display (handles both staged and non-staged cards)
  # For foil-only cards, uses foil_price for all quantities
  # For non-staged cards, includes both real and proxy values
  def display_value
    normal_price = magic_card.normal_price.to_f
    foil_price = magic_card.foil_price.to_f

    return display_quantity * foil_price if foil_only_card?(normal_price, foil_price)
    return staged_value(normal_price, foil_price) if staged?

    real_value + proxy_value
  end

  def staged_value(normal_price, foil_price)
    ((staged_quantity + staged_proxy_quantity) * normal_price) +
      ((staged_foil_quantity + staged_proxy_foil_quantity) * foil_price)
  end

  def foil_only_card?(normal_price, foil_price)
    normal_price.zero? && foil_price.positive?
  end

  # Build mode methods
  def planned?
    staged? && source_collection_id.nil?
  end

  def from_owned_collection?
    staged? && source_collection_id.present?
  end

  def total_staged
    staged_quantity + staged_foil_quantity + staged_proxy_quantity + staged_proxy_foil_quantity
  end

  def display_quantity
    staged? ? total_staged : (total_regular + total_foil)
  end

  def available_swap?(user)
    needed? && magic_card.user_owned_copies(user).any?
  end

  def commander?
    board_type == 'commander'
  end
end
