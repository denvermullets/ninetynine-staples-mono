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
  scope :commanders, -> { where(board_type: 'commander') }

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
    (quantity * magic_card.normal_price.to_f) + (foil_quantity * magic_card.foil_price.to_f)
  end

  def proxy_value
    ((proxy_quantity || 0) * magic_card.proxy_normal_price) +
      ((proxy_foil_quantity || 0) * magic_card.proxy_foil_price)
  end

  # True when every copy on this row is a foil (regular or proxy)
  def foil_only?
    breakdown = display_quantity_breakdown
    breakdown.any? && breakdown.keys.all? { |finish| finish.to_s.end_with?('foil') }
  end

  # Price shown in the deck list. Rows holding only foils price as foil; mixed
  # rows fall back to the regular price since the quantity breakdown already
  # shows the split.
  def display_unit_price
    return magic_card.foil_price.to_f if foil_only? && magic_card.foil_price.to_f.positive?

    magic_card.display_price.to_f
  end

  # Value for deck builder display - summed per finish so group subtotals
  # agree with the foil-aware deck totals
  def display_value
    display_quantity_breakdown.sum do |finish, qty|
      qty * unit_price_for(finish)
    end
  end

  def staged_real_value
    (staged_quantity * magic_card.normal_price.to_f) + (staged_foil_quantity * magic_card.foil_price.to_f)
  end

  def staged_proxy_value
    (staged_proxy_quantity * magic_card.proxy_normal_price) + (staged_proxy_foil_quantity * magic_card.proxy_foil_price)
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

  def display_quantity_breakdown
    raw = if staged?
            { regular: staged_quantity, foil: staged_foil_quantity,
              proxy: staged_proxy_quantity, proxy_foil: staged_proxy_foil_quantity }
          else
            { regular: quantity, foil: foil_quantity,
              proxy: proxy_quantity || 0, proxy_foil: proxy_foil_quantity || 0 }
          end
    raw.select { |_, v| v.positive? }
  end

  def available_swap?(user)
    needed? && magic_card.user_owned_copies(user).any?
  end

  def commander?
    board_type == 'commander'
  end

  private

  def unit_price_for(finish)
    case finish
    when :foil then foil_price_with_fallback
    when :proxy then magic_card.proxy_normal_price
    when :proxy_foil then magic_card.proxy_foil_price
    else magic_card.display_price.to_f
    end
  end

  def foil_price_with_fallback
    magic_card.foil_price.to_f.positive? ? magic_card.foil_price.to_f : magic_card.display_price.to_f
  end
end
