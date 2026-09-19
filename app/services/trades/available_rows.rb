# The rows a user can actually put on the table right now, one per collection row rather than per
# printing: Trades::Propose is given collection_magic_card_ids, so the builder has to offer the same
# granularity the proposal is written in.
#
# The builder opens on the trade list, but a row is not capped at it: a trade can ask for any real
# copy in a public collection (User#offerable_cards), so `quantity` / `foil_quantity` are the copies
# owned and `listed_*` are how many of those are on the trade list. The builder flags anything past
# the listed count. Rows that are not on the trade list at all are not here - there can be thousands
# of them, so the builder searches for those through Trades::UnlistedRows, which hands its own
# `scope` to this service. `also` names the exceptions: rows a counter-offer's original already holds,
# which have to be on the page for the draft to start from them, listed or not.
#
# Both counts are net of the copies Trades::Committed says are already spoken for by the user's
# other open trades, and a committed copy is taken off the trade list first - the list is what the
# owner would rather part with. A row with nothing left after that subtraction is dropped.
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
    Row = Data.define(:id, :magic_card, :collection_name, :quantity, :foil_quantity,
                      :listed_quantity, :listed_foil_quantity) do
      def unlisted?
        listed_quantity.zero? && listed_foil_quantity.zero?
      end
    end

    def initialize(user:, except_trade: nil, also: [], scope: nil)
      @user = user
      @except_trade = except_trade
      @also = Array(also).compact
      @scope = scope
    end

    def call
      rows.filter_map { |row| available(row) }
    end

    private

    # memoised because the committed lookup below has to be keyed on exactly this set of rows
    def rows
      @rows ||= (@scope || listed)
                .includes(:collection, magic_card: :boxset)
                .references(:magic_card)
                .order('magic_cards.name ASC')
                .to_a
    end

    def listed
      @user.offerable_cards.where(
        'trade_quantity > 0 OR trade_foil_quantity > 0 OR collection_magic_cards.id IN (?)', @also.presence || [nil]
      )
    end

    def committed
      @committed ||= Committed.call(user: @user, collection_magic_card_ids: rows.map(&:id), except_trade: @except_trade)
    end

    def available(row)
      owned = remaining(row, row.quantity, row.foil_quantity)
      return nil unless owned.any?(&:positive?)

      listed = remaining(row, row.trade_quantity, row.trade_foil_quantity)
      Row.new(id: row.id, magic_card: row.magic_card, collection_name: row.collection.name,
              quantity: owned.first, foil_quantity: owned.last,
              listed_quantity: listed.first, listed_foil_quantity: listed.last)
    end

    # [regular, foil] once the copies other open trades hold are taken off, never below zero
    def remaining(row, regular, foil)
      spoken_for = committed[row.id]

      [[regular.to_i - spoken_for[:quantity], 0].max, [foil.to_i - spoken_for[:foil_quantity], 0].max]
    end
  end
end
