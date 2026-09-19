# How many of a user's copies are already spoken for by their other open trades.
#
# A collection row's trade_quantity doesn't move when a trade is proposed or accepted - only when one
# completes - so it is the ceiling, not the balance. This is the part subtracted from it: the same
# copies sitting in every proposed or accepted trade the user is on either side of.
#
# Returns a hash keyed by collection_magic_card_id, defaulting to zeroes so a row with no open trades
# reads the same as one that has them.
module Trades
  class Committed < Service
    ZERO = { quantity: 0, foil_quantity: 0 }.freeze

    def initialize(user:, collection_magic_card_ids:, except_trade: nil)
      @user = user
      @ids = Array(collection_magic_card_ids).compact
      @except_trade = except_trade
    end

    def call
      totals = Hash.new { |hash, key| hash[key] = ZERO.dup }
      return totals if @ids.empty?

      rows.each do |id, quantity, foil_quantity|
        totals[id] = { quantity: quantity.to_i, foil_quantity: foil_quantity.to_i }
      end

      totals
    end

    private

    def rows
      scope.group(:collection_magic_card_id)
           .pluck(:collection_magic_card_id, Arel.sql('SUM(quantity)'), Arel.sql('SUM(foil_quantity)'))
    end

    # side has to match which end of the trade the user is on - a row of theirs can only ever be
    # offered from their own side, and counting the other side would charge them for the cards they
    # are receiving
    def scope
      base = TradeItem.joins(:trade).where(collection_magic_card_id: @ids).merge(Trade.open)
      base = base.where.not(trade_id: @except_trade.id) if @except_trade&.id
      base.where(
        'trades.proposer_id = :user AND trade_items.side = :proposer OR ' \
        'trades.recipient_id = :user AND trade_items.side = :recipient',
        user: @user.id, proposer: 'proposer', recipient: 'recipient'
      )
    end
  end
end
