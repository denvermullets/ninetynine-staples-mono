# The rows a user can actually put on the table right now, one per collection row rather than per
# printing: Trades::Propose is given collection_magic_card_ids, so the builder has to offer the same
# granularity the proposal is written in.
#
# Availability is trade_quantity minus the copies Trades::Committed says are already spoken for by
# the user's other open trades. A row with nothing left after that subtraction is dropped - it is on
# their trade list, but every copy of it is already in somebody else's proposal.
#
# A counter-offer passes the trade it answers as except_trade. Those copies are still committed while
# the builder is open, but they are the ones being put back on the table - left in, both sides of the
# original would come up short in its own counter.
#
# The counts on each row are what the builder's quantity inputs are capped at. They are a courtesy,
# not the guard: Propose re-checks availability at proposal time, because the page may have been
# open while another trade was accepted.
module Trades
  class AvailableRows < Service
    Row = Data.define(:id, :magic_card, :collection_name, :quantity, :foil_quantity)

    def initialize(user:, except_trade: nil)
      @user = user
      @except_trade = except_trade
    end

    def call
      rows.filter_map { |row| available(row) }
    end

    private

    # memoised because the committed lookup below has to be keyed on exactly this set of rows
    def rows
      @rows ||= @user.tradeable_cards
                     .includes(:collection, magic_card: :boxset)
                     .references(:magic_card)
                     .order('magic_cards.name ASC')
                     .to_a
    end

    def committed
      @committed ||= Committed.call(user: @user, collection_magic_card_ids: rows.map(&:id), except_trade: @except_trade)
    end

    def available(row)
      spoken_for = committed[row.id]
      quantity = row.trade_quantity - spoken_for[:quantity]
      foil_quantity = row.trade_foil_quantity - spoken_for[:foil_quantity]
      return nil unless quantity.positive? || foil_quantity.positive?

      Row.new(id: row.id, magic_card: row.magic_card, collection_name: row.collection.name,
              quantity: [quantity, 0].max, foil_quantity: [foil_quantity, 0].max)
    end
  end
end
