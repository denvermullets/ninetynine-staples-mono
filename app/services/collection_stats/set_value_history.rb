# What the copies you hold from one set were worth on each day the prices were recorded.
#
# The set page's "Your Copies" tile is one number for today; this is that number drawn backwards.
# It is the cards you hold NOW priced at each day's price, not a record of what the collection was
# worth on that day - nothing stores when a copy was acquired, so the line answers "how have my
# cards moved", not "what did I own in March".
#
# Same rows and same rule as the tile: real copies only (REAL_COPIES on the join, REAL_VALUE's
# pairing of qty with normal and foil_qty with foil), tokens and back faces out. The last point
# therefore lands on the tile's figure whenever today's price ingest has run.
#
# Built in Ruby rather than unnesting price_history in SQL: one query plucks the holdings, and a
# set is a few hundred printings by ninety-odd days, which is cheap to walk.
module CollectionStats
  class SetValueHistory < Base
    include SetBasis

    def initialize(collection_ids:, boxset:)
      super(collection_ids: collection_ids)
      @boxset = boxset
    end

    # { 'YYYY-MM-DD' => value }, oldest first - the shape the collection history chart already reads
    def call
      return {} if no_collections?

      holdings = owned_holdings
      dates = holdings.flat_map { |holding| holding[:prices].values.flat_map(&:keys) }.uniq.sort

      dates.index_with(0.0).tap do |totals|
        holdings.each { |holding| add_holding(totals, holding, dates) }
        totals.transform_values! { |value| value.round(2) }
      end
    end

    private

    def owned_holdings
      owned_cards
        .where(boxset_id: @boxset.id, is_token: false)
        .where(PRINTABLE)
        .where(REAL_COPIES)
        .pluck(Arel.sql('owned.qty'), Arel.sql('owned.foil_qty'), :price_history)
        .map do |qty, foil_qty, history|
          { qty: { 'normal' => qty.to_i, 'foil' => foil_qty.to_i }, prices: prices_by_finish(history) }
        end
    end

    def prices_by_finish(history)
      return {} if history.blank?

      %w[normal foil].index_with do |finish|
        Array(history[finish]).each_with_object({}) { |entry, prices| prices.merge!(entry) }
      end
    end

    # A day missing from a card's history keeps the last price it had rather than dropping to zero -
    # the ingest bridges gaps the same way, and a hole would read as the card going worthless for a
    # day. Before a card's first recorded price there is nothing to carry, so it adds nothing.
    def add_holding(totals, holding, dates)
      holding[:qty].each do |finish, qty|
        next if qty.zero?

        prices = holding[:prices][finish] || {}
        last = nil

        dates.each do |date|
          last = prices[date].to_f if prices.key?(date)
          totals[date] += qty * last if last
        end
      end
    end
  end
end
