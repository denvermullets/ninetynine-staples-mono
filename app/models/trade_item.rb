# One printing on one side of a trade, with the prices it carried when the trade was proposed.
#
# The snapshots are copied from magic_cards at proposal time and never refreshed: a trade is judged
# on the numbers both parties agreed to, not on what the card is worth by the time it is accepted.
#
# collection_magic_card is optional because the owner can delete the binder row afterwards. The item
# keeps magic_card_id so a finished trade still reads correctly; a nil row just means the copies are
# no longer traceable to a collection, which only matters while the trade is open.
class TradeItem < ApplicationRecord
  belongs_to :trade
  belongs_to :collection_magic_card, optional: true
  belongs_to :magic_card

  validates :side, inclusion: { in: Trade::SIDES }
  validates :quantity, :foil_quantity, numericality: { greater_than_or_equal_to: 0 }
  validate :offers_a_copy

  scope :for_side, ->(side) { where(side: side.to_s) }

  def total_copies
    quantity + foil_quantity
  end

  # Both sides of the fallback in Trades::UnitPrice apply to the snapshots too: an item whose foil
  # price was zero at proposal time is valued at the regular price, so a side's snapshot total and
  # its live total in Trades::Valuation are the same arithmetic on different prices.
  def retail_value
    Trades::UnitPrice.value(quantity: quantity, foil_quantity: foil_quantity,
                            normal: unit_price_snapshot, foil: unit_foil_price_snapshot)
  end

  def buylist_value
    Trades::UnitPrice.value(quantity: quantity, foil_quantity: foil_quantity,
                            normal: unit_buylist_snapshot, foil: unit_buylist_foil_snapshot)
  end

  private

  def offers_a_copy
    errors.add(:base, 'must offer at least one copy') unless total_copies.positive?
  end
end
