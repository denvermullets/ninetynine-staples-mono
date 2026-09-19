# Everyone with one want up for trade - the page behind a row on the want list, the way a Discogs
# wantlist row leads to the people selling that record.
#
# Marked copies only: this page exists to propose a trade from, so somebody who merely owns the card
# is left to the matches page. It reads the same set MagicCards::TradeHolders does - tradeable copies
# in public collections of people whose trade list is public - minus the follow restriction, and never
# the wanter's own. The match rule is WantListItem.matching's, decided in Ruby because there is only
# the one want: an any-printing want lists every printing on offer, a foil-only want counts no
# regular copies.
#
# One row per trader per printing, summed over their public collections. People the viewer follows
# come first, then the printing the want points at, then whoever has the most copies. The row count
# is unbounded in the number of users, so `offers` comes back as a relation for the controller to
# page like any other list, and `present` turns the page it took into Traders. `total` is the number
# of rows, for pagy's count:; `traders` is how many people are behind them.
module WantList
  class Traders < Service
    PER_PAGE = 50

    Trader = Data.define(:user, :printing, :quantity, :foil_quantity, :value, :followed) do
      def copies
        quantity + foil_quantity
      end
    end

    # the trade counts each foil preference leaves standing
    FINISH_COLUMNS = {
      'any' => %w[trade_quantity trade_foil_quantity],
      'foil' => %w[trade_foil_quantity],
      'non_foil' => %w[trade_quantity]
    }.freeze

    # trader counts per foil preference, so one grouped query answers for wants of every preference
    TRADER_COUNTS = {
      'any' => 'COUNT(DISTINCT collections.user_id)',
      'foil' => 'COUNT(DISTINCT collections.user_id) FILTER (WHERE collection_magic_cards.trade_foil_quantity > 0)',
      'non_foil' => 'COUNT(DISTINCT collections.user_id) FILTER (WHERE collection_magic_cards.trade_quantity > 0)'
    }.transform_values { |sql| Arel.sql(sql) }.freeze

    def initialize(want:)
      @want = want
    end

    def call
      { offers: rows, total: total, traders: offers.distinct.count('collections.user_id') }
    end

    # Traders for a page of `offers`
    def self.present(records)
      users = User.where(id: records.map(&:holder_id).uniq).index_by(&:id)
      printings = MagicCard.includes(:boxset).where(id: records.map(&:magic_card_id).uniq).index_by(&:id)

      records.map { |record| trader(record, users[record.holder_id], printings[record.magic_card_id]) }
    end

    def self.trader(record, user, printing)
      quantity = record.offered_quantity.to_i
      foil_quantity = record.offered_foil_quantity.to_i

      Trader.new(user: user, printing: printing, quantity: quantity, foil_quantity: foil_quantity,
                 followed: record.followed,
                 value: Trades::UnitPrice.value(quantity: quantity, foil_quantity: foil_quantity,
                                                normal: printing.normal_price, foil: printing.foil_price))
    end
    private_class_method :trader

    # { want_id => number of traders } for a page of one user's wants - the count a want list row
    # links to this page with. A want nobody is offering is absent. Two grouped queries, one per way
    # a want can match, rather than one per want.
    def self.counts(wants:, viewer:)
      return {} if viewer.nil?

      by_oracle, by_printing = wants.select { |want| want.user_id == viewer.id }.partition(&:matches_by_oracle?)
      offers = offers_to(viewer.id)
      oracle_offers = offers.joins(:magic_card).where(magic_cards: { card_side: [nil, 'a'] })

      tally(by_printing, offers, 'collection_magic_cards.magic_card_id', &:magic_card_id)
        .merge(tally(by_oracle, oracle_offers, 'magic_cards.scryfall_oracle_id', &:scryfall_oracle_id))
    end

    # marked copies somebody could be offered: public collection, public trade list, not their own
    def self.offers_to(viewer_id)
      CollectionMagicCard.tradeable
                         .merge(Collection.visible_to_public)
                         .joins(collection: :user)
                         .where(users: { trades_public: true })
                         .where.not(collections: { user_id: viewer_id })
    end

    def self.tally(wants, offers, column, &key)
      return {} if wants.empty?

      counts = offers.where(column => wants.map(&key)).group(column).pluck(column, *TRADER_COUNTS.values)
                     .to_h { |value, *per_finish| [value, TRADER_COUNTS.keys.zip(per_finish).to_h] }
      wants.filter_map do |want|
        count = counts.dig(key.call(want), want.foil_preference).to_i
        [want.id, count] if count.positive?
      end.to_h
    end
    private_class_method :tally

    private

    def offers
      @offers ||= self.class.offers_to(@want.user_id).where(magic_card_id: printing_ids)
                      .where(finish_columns.map { |column| copies[column].gt(0) }.reduce(:or))
    end

    def printing_ids
      return @want.magic_card_id unless @want.matches_by_oracle?

      MagicCard.where(scryfall_oracle_id: @want.scryfall_oracle_id, card_side: [nil, 'a']).select(:id)
    end

    def finish_columns
      FINISH_COLUMNS.fetch(@want.foil_preference)
    end

    def copies
      CollectionMagicCard.arel_table
    end

    # a finish the want does not accept sums to nothing
    def sum(column)
      finish_columns.include?(column) ? copies[column].sum : Arel.sql('0')
    end

    def grouped
      offers.group('collections.user_id', 'collection_magic_cards.magic_card_id')
    end

    def total
      CollectionMagicCard.unscoped.from(grouped.select('1'), :offers).count
    end

    def followed
      Collection.arel_table[:user_id].in(Follow.where(follower_id: @want.user_id).select(:followed_id).arel)
    end

    def rows
      grouped.group('users.username').order(*ordering)
             .select(Collection.arel_table[:user_id].as('holder_id'), copies[:magic_card_id],
                     sum('trade_quantity').as('offered_quantity'),
                     sum('trade_foil_quantity').as('offered_foil_quantity'), followed.as('followed'))
    end

    def ordering
      wanted = copies[:magic_card_id].eq(@want.magic_card_id)
      offered = Arel::Nodes::Addition.new(sum('trade_quantity'), sum('trade_foil_quantity'))

      [Arel::Nodes::Descending.new(followed), Arel::Nodes::Descending.new(wanted),
       Arel::Nodes::Descending.new(offered),
       Arel.sql('LOWER(users.username) ASC'), 'collection_magic_cards.magic_card_id']
    end
  end
end
