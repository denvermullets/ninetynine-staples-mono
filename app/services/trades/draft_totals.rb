# What a trade is worth while it is still being built, before any of it exists in the database.
#
# The builder keeps its draft client-side, so the page posts a list of (collection row, side,
# quantities) and gets back the same shape Trades::Valuation returns for a saved trade: totals per
# side, and the difference between them at today's prices. There is no snapshot half - nothing has
# been agreed yet, so there is nothing to have drifted from.
#
# Every row is resolved against its side's owner before it is priced. The ids come from the page, and
# a row that is not a real copy in one of that user's public collections is not theirs to offer -
# pricing it anyway would show both parties a total the proposal is about to refuse.
#
# Quantities are taken as sent. The inputs are capped at what is available and Trades::Propose is the
# thing that enforces it; a draft that asks for more copies than exist is priced honestly, and then
# rejected on submit.
module Trades
  class DraftTotals < Service
    def initialize(proposer:, recipient:, items:)
      @proposer = proposer
      @recipient = recipient
      @items = Array(items).map { |item| item.to_h.symbolize_keys }
    end

    def call
      sides = { proposer: SideTotal.call(items: tuples('proposer')),
                recipient: SideTotal.call(items: tuples('recipient')) }

      sides.merge(difference: sides[:recipient][:retail] - sides[:proposer][:retail])
    end

    private

    def tuples(side)
      owned = rows(side)

      @items.filter_map do |item|
        next unless item[:side].to_s == side

        row = owned[item[:collection_magic_card_id].to_i]
        next if row.nil?

        { magic_card_id: row.magic_card_id, quantity: item[:quantity].to_i,
          foil_quantity: item[:foil_quantity].to_i }
      end
    end

    def rows(side)
      owner = side == 'proposer' ? @proposer : @recipient
      ids = @items.select { |item| item[:side].to_s == side }.map { |item| item[:collection_magic_card_id] }

      owner.offerable_cards.where(id: ids).index_by(&:id)
    end
  end
end
