# The trade state machine. Every status change goes through here so the wrong-party guards live in
# one place instead of in each controller action.
#
#   proposed            -> accepted | declined   (recipient only - it is their offer to answer)
#   proposed | accepted -> cancelled             (either party can walk away)
#   accepted            -> completed             (both parties confirm separately)
#
# Completion is two-sided on purpose: `complete` stamps the calling party's column and stops there.
# The trade only lands on `completed` once the other party has stamped theirs too, which is the point
# at which the cards have actually changed hands.
#
# Every step lands on the trade's timeline as a TradeEvent, written in the same transaction, and every
# status change notifies the other party. One party's receipt confirmation is not a status change on
# its own, so only the second one - the one that completes the trade - notifies anybody.
#
# That final step is the only moment a trade writes to a collection, and all it writes is the
# trade_* counts: the copies are no longer on offer because they are gone. `quantity` is left alone.
# This app is a ledger of trades, not an inventory system that moves cards between users.
module Trades
  class Transition < Service
    EVENTS = %w[accept decline cancel complete].freeze

    # The events `user` could fire on `trade` right now - the same guards #call runs, so a button on
    # the trade page is never offered for a step the state machine would refuse.
    def self.allowed_events(trade:, user:)
      EVENTS.select { |event| new(trade: trade, user: user, event: event).allowed? }
    end

    def initialize(trade:, user:, event:)
      @trade = trade
      @user = user
      @event = event.to_s
    end

    def call
      error = guard
      return { success: false, error: error } if error

      ActiveRecord::Base.transaction do
        status = @trade.status
        send(:"apply_#{@event}")
        notify_counterparty if @trade.status != status
      end
      { success: true, trade: @trade }
    end

    def allowed?
      guard.nil?
    end

    private

    def guard
      return 'Unknown trade action.' unless EVENTS.include?(@event)
      return 'This is not your trade.' unless @trade.party?(@user)

      send(:"guard_#{@event}")
    end

    def guard_accept
      recipient_only || must_be('proposed')
    end

    def guard_decline
      recipient_only || must_be('proposed')
    end

    def guard_cancel
      return nil if @trade.open?

      "A #{@trade.status} trade can no longer be cancelled."
    end

    def guard_complete
      return 'Only an accepted trade can be completed.' unless @trade.accepted?
      return 'You have already confirmed this trade.' if @trade.confirmed_by?(@user)

      nil
    end

    def recipient_only
      return nil if @user.id == @trade.recipient_id

      'Only the recipient can answer this trade.'
    end

    def must_be(status)
      return nil if @trade.status == status

      "This trade is already #{@trade.status}."
    end

    def apply_accept
      @trade.update!(status: 'accepted')
      record('accepted')
    end

    def apply_decline
      @trade.update!(status: 'declined')
      record('declined')
    end

    def apply_cancel
      @trade.update!(status: 'cancelled')
      record('cancelled')
    end

    # one party's confirmation; the trade only closes when the second one arrives
    def apply_complete
      @trade.update!("#{@trade.side_for(@user)}_completed_at": Time.current)
      record('confirmed')
      return unless @trade.proposer_completed_at? && @trade.recipient_completed_at?

      @trade.update!(status: 'completed')
      record('completed', user: nil)
      release_traded_copies
    end

    def notify_counterparty
      Notifications::Deliver.call(user: @trade.counterparty(@user), kind: "trade_#{@trade.status}", notifiable: @trade)
    end

    def record(event, user: @user)
      @trade.trade_events.create!(user: user, event: event)
    end

    # Items whose collection row was deleted in the meantime have nothing left to decrement, which is
    # fine - the copies already stopped being on offer when the row went away.
    # An item that reached past the trade list clamps at zero for the same reason `quantity` is left
    # alone: the unlisted copies were never counted here, so there is nothing of theirs to take off.
    def release_traded_copies
      @trade.trade_items.includes(:collection_magic_card).each do |item|
        row = item.collection_magic_card
        next if row.nil?

        row.update!(
          trade_quantity: [row.trade_quantity - item.quantity, 0].max,
          trade_foil_quantity: [row.trade_foil_quantity - item.foil_quantity, 0].max
        )
      end
    end
  end
end
