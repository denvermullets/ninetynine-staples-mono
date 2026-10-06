# Every printing in the given collections, one row per finish actually held, with that finish's
# market and Card Kingdom buylist price: what PriceAlerts::SyncBand walks to place each card against
# a price band.
#
# Real copies only, like every money figure in CollectionStats: a proxy is not worth sleeving up,
# and it has no price to cross anything with. `finish` narrows to one finish ('any' keeps both).
module CollectionStats
  class FinishHoldings < Base
    COLUMNS = {
      'normal' => { qty: 'owned.qty', price: 'magic_cards.normal_price',
                    buylist: 'magic_cards.ck_buylist_normal_price' },
      'foil' => { qty: 'owned.foil_qty', price: 'magic_cards.foil_price',
                  buylist: 'magic_cards.ck_buylist_foil_price' }
    }.freeze

    def self.for_band(band)
      scope = Scope.call(username: band.user.username, viewer: band.user, collection_id: band.collection_id)

      new(collection_ids: scope[:collection_ids], finish: band.finish)
    end

    def initialize(collection_ids:, finish: 'any')
      super(collection_ids: collection_ids)
      @finishes = COLUMNS.key?(finish) ? [finish] : COLUMNS.keys
    end

    def call
      return [] if no_collections?

      @finishes.flat_map do |finish|
        columns = COLUMNS.fetch(finish)
        owned_cards.where(Arel.sql("#{columns[:qty]} > 0"))
                   .pluck('magic_cards.id', 'magic_cards.name', Arel.sql(columns[:price]), Arel.sql(columns[:buylist]))
                   .map do |id, name, price, buylist|
          { magic_card_id: id, name: name, finish: finish, price: price, buylist: buylist }
        end
      end
    end
  end
end
