# The builder's starting quantities for a counter-offer: the trade being answered, turned around.
#
# Nothing needs swapping by hand. The builder's rows are collection rows and each one belongs to one
# user, so the parent's recipient-side items land on the counter's "You give" column and its
# proposer-side items on "They give" just by being looked up by row.
#
# `rows` is every Trades::AvailableRows::Row on both sides, built with the parent as except_trade.
# Each quantity is capped at what the row can offer now, and an item whose row is gone or no longer
# on offer is dropped - the builder can only draft cards it can show.
#
# Returns { row_id => { quantity:, foil_quantity: } }, the same shape as a plain "Add to trade"
# preselection.
module Trades
  class CounterDraft < Service
    def initialize(parent:, rows:)
      @parent = parent
      @rows = rows.index_by(&:id)
    end

    def call
      requested.each_with_object({}) do |(row_id, wanted), draft|
        row = @rows[row_id]
        next if row.nil?

        draft[row_id] = { quantity: [wanted[:quantity], row.quantity].min,
                          foil_quantity: [wanted[:foil_quantity], row.foil_quantity].min }
      end
    end

    private

    def requested
      @parent.trade_items.each_with_object({}) do |item, totals|
        next if item.collection_magic_card_id.nil?

        total = totals[item.collection_magic_card_id] ||= { quantity: 0, foil_quantity: 0 }
        total[:quantity] += item.quantity
        total[:foil_quantity] += item.foil_quantity
      end
    end
  end
end
