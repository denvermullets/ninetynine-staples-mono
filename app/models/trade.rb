# A proposal between two users with cards on each side. A trade is a ledger entry and nothing more:
# it never moves a card between collections. The only collection data it ever writes is the
# trade_quantity / trade_foil_quantity counts, decremented once both parties confirm completion -
# the copies left the binder in real life, so they stop being on offer.
class Trade < ApplicationRecord
  SIDES = %w[proposer recipient].freeze
  OPEN_STATUSES = %w[proposed accepted].freeze

  enum :status, %w[proposed accepted declined cancelled completed].index_by(&:itself)

  belongs_to :proposer, class_name: 'User'
  belongs_to :recipient, class_name: 'User'
  # counter-offers: reserved, nothing creates one yet
  belongs_to :parent_trade, class_name: 'Trade', optional: true
  has_many :counter_offers, class_name: 'Trade', foreign_key: :parent_trade_id, dependent: :nullify,
                            inverse_of: :parent_trade

  has_many :trade_items, dependent: :destroy

  validates :proposer_id, comparison: { other_than: :recipient_id }

  scope :open, -> { where(status: OPEN_STATUSES) }
  scope :involving, ->(user) { where(proposer_id: user).or(where(recipient_id: user)) }

  def items_for(side)
    trade_items.select { |item| item.side == side.to_s }
  end

  # Still live: either side can still act on it, and its copies are still spoken for.
  def open?
    OPEN_STATUSES.include?(status)
  end

  def party?(user)
    [proposer_id, recipient_id].include?(user&.id)
  end

  def counterparty(user)
    return recipient if user&.id == proposer_id
    return proposer if user&.id == recipient_id

    nil
  end

  def side_for(user)
    return 'proposer' if user&.id == proposer_id
    return 'recipient' if user&.id == recipient_id

    nil
  end

  def user_for_side(side)
    side.to_s == 'proposer' ? proposer : recipient
  end

  def completed_at_for(side)
    side.to_s == 'proposer' ? proposer_completed_at : recipient_completed_at
  end

  def confirmed_by?(user)
    side = side_for(user)
    side.present? && completed_at_for(side).present?
  end
end
