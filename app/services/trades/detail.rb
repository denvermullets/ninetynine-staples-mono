# Everything the trade page shows, turned to face whoever is looking at it.
#
# Trades::Valuation reads proposer vs recipient; the page reads "them" vs "you", so `difference` and
# `live_difference` here are what the viewer receives minus what they give - positive is value
# coming their way, whichever side of the trade they are on. Both are at snapshot prices first,
# because that is the deal both parties were shown; the live one only backs the drift badge.
#
# `actions` are the Trades::Transition events the viewer can fire right now, straight from its
# guards, so the page never offers a button the state machine would refuse. Countering is not one of
# them - it writes a new trade rather than moving this one - so `counter?` rides alongside, from the
# same rule Trades::Propose checks.
#
# `parent` and `counter_offer` are the trades either side of this one in a counter-offer chain. Both
# have the same two parties, so linking to them never shows the viewer a trade they are not on.
#
# `timeline` is the whole of that chain rather than this trade's leg of it - Trades::Thread.
#
# Only for a party to the trade - the controller has already 404'd everyone else.
module Trades
  class Detail < Service
    def initialize(trade:, viewer:)
      @trade = trade
      @viewer = viewer
    end

    def call
      valuation = Valuation.call(trade: @trade)
      mine = @trade.side_for(@viewer)
      theirs = (Trade::SIDES - [mine]).first
      sign = mine == 'proposer' ? 1 : -1

      { mine: side(mine, valuation), theirs: side(theirs, valuation),
        difference: valuation[:difference] * sign, live_difference: valuation[:live_difference] * sign,
        drift?: valuation[:drift?],
        actions: Transition.allowed_events(trade: @trade, user: @viewer),
        counter?: @trade.counterable_by?(@viewer),
        parent: @trade.parent_trade, counter_offer: @trade.counter_offers.max_by(&:id),
        timeline: Thread.call(trade: @trade) }
    end

    private

    def side(name, valuation)
      totals = valuation[name.to_sym]

      { name: name, user: @trade.user_for_side(name), items: @trade.items_for(name),
        retail: totals[:retail_snapshot], buylist: totals[:buylist_snapshot], live_retail: totals[:retail],
        copies: totals[:copies], confirmed_at: @trade.completed_at_for(name) }
    end
  end
end
