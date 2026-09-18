# One line on a trade's timeline: who did what, and when.
#
# Written by Trades::Propose and Trades::Transition in the same transaction as the change it records,
# never by a caller. The trade's own columns only hold where it is now - updated_at is overwritten by
# every later step, so without this the moment a trade was accepted is gone as soon as either party
# confirms receipt.
#
# `countered` stands in for `declined` on a trade the recipient answered with a counter-offer: the
# status is declined either way, and this is the one place the reason is kept.
#
# `confirmed` is one party's "I've received my cards"; `completed` is the trade closing once both are
# in, and has no user of its own.
class TradeEvent < ApplicationRecord
  EVENTS = %w[proposed accepted declined countered cancelled confirmed completed].freeze

  belongs_to :trade
  belongs_to :user, optional: true

  validates :event, inclusion: { in: EVENTS }
end
