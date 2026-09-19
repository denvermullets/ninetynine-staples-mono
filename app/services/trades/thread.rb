# The whole negotiation a trade belongs to, oldest step first: the first offer, every counter-offer
# that answered it, and whatever happened to the last of them.
#
# A counter-offer is a trade of its own (Trades::Propose), so a trade's events and message only ever
# cover its own leg. Read alone, the page for a counter opens on "proposed the trade" with the offer
# it answered, and everything said along the way, nowhere to be seen. This stitches the legs back
# together, and hangs each trade's message on the step that sent it so the discussion reads in order.
#
# The `countered` event is left out: the counter's own `proposed` step lands in the same transaction
# and says the same thing, with the message and the offer to go with it.
#
# Every trade in a chain has the same two parties, so a viewer of one leg may read them all.
module Trades
  class Thread < Service
    def initialize(trade:)
      @trade = trade
    end

    def call
      trades = chain.index_by(&:id)

      TradeEvent.where(trade_id: trades.keys).where.not(event: 'countered')
                .includes(:user).order(:created_at, :id).map do |event|
        leg = trades[event.trade_id]
        { event: event, trade: leg, current: leg.id == @trade.id,
          message: (leg.message.presence if event.event == 'proposed') }
      end
    end

    private

    def chain
      ancestors.reverse + [@trade] + descendants
    end

    def ancestors
      walk(&:parent_trade)
    end

    # a trade is declined the moment it is countered, so it can only ever have the one counter-offer
    def descendants
      walk { |trade| Trade.where(parent_trade_id: trade.id).order(:id).last }
    end

    def walk
      found = []
      current = @trade
      found << current while (current = yield(current))
      found
    end
  end
end
