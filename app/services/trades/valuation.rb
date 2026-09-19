# What each side of a trade is worth, at the prices both parties agreed to and at today's prices.
#
# Per side: `retail` / `buylist` priced live, `retail_snapshot` / `buylist_snapshot` from the prices
# copied onto the items at proposal time, and `copies`.
#
# `difference` is the recipient's snapshot retail minus the proposer's - the gap in the deal as it
# was agreed, positive when the recipient is putting up more value. `live_difference` is the same gap
# at today's prices. The snapshot is the headline because that is what both parties were shown, and
# `drift?` says the prices behind it have moved since.
#
# None of this decides anything. A lopsided trade is a perfectly good trade if both players want it -
# these are numbers to show them, never a rule to enforce. Nothing here blocks, warns off, or scores
# a proposal, and no caller should start doing so on its behalf.
#
# Drift threshold: 5% of the side's snapshot retail or $1, whichever is larger. The percentage alone
# would flag every cheap side (a bulk rare ticking up a dime is 10%), the dollar alone would flag
# every expensive one. Worth revisiting once there are real trades to look at.
module Trades
  class Valuation < Service
    DRIFT_PERCENT = '0.05'.to_d
    DRIFT_FLOOR = '1'.to_d

    def initialize(trade:)
      @trade = trade
    end

    def call
      sides = { proposer: side(:proposer), recipient: side(:recipient) }

      sides.merge(
        difference: sides[:recipient][:retail_snapshot] - sides[:proposer][:retail_snapshot],
        live_difference: sides[:recipient][:retail] - sides[:proposer][:retail],
        drift?: sides.each_value.any? { |totals| totals[:drift?] }
      )
    end

    private

    def side(name)
      items = @trade.items_for(name)
      live = SideTotal.call(items: items.map { |item| tuple(item) })
      snapshot = items.sum(0.to_d, &:retail_value)

      live.merge(retail_snapshot: snapshot, buylist_snapshot: items.sum(0.to_d, &:buylist_value),
                 drift?: drift?(live[:retail], snapshot))
    end

    def tuple(item)
      { magic_card_id: item.magic_card_id, quantity: item.quantity, foil_quantity: item.foil_quantity }
    end

    def drift?(live, snapshot)
      (live - snapshot).abs > [DRIFT_FLOOR, snapshot * DRIFT_PERCENT].max
    end
  end
end
