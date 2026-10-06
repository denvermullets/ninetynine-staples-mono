# A price band's worklist as rows to draw: the cards that crossed it and still need handling, or,
# with `done`, the ones most recently ticked off (DONE_LIMIT of them, newest first).
#
# Each row says where the card is - every collection holding the finish that crossed, and how many
# copies - since the point of the list is going and finding the card. The to-do list sorts the moves
# up ahead of the moves down, then by the first of those collections and then by name, so each swap
# reads binder by binder.
#
# Real copies only, matching CollectionStats::FinishHoldings: a collection holding nothing but
# proxies of a card is not somewhere it needs sleeving.
module PriceAlerts
  class BandWorklist < Service
    DONE_LIMIT = 100
    PRICE = { 'normal' => %i[normal_price ck_buylist_normal_price],
              'foil' => %i[foil_price ck_buylist_foil_price] }.freeze
    QTY = { 'normal' => :quantity, 'foil' => :foil_quantity }.freeze

    def initialize(band:, done: false)
      @band = band
      @done = done
    end

    def call
      cards = band_cards.to_a
      places = places_for(cards)
      rows = cards.map { |card| build_row(card, places.fetch([card.magic_card_id, card.finish], [])) }

      @done ? rows : rows.sort_by { |row| binder_order(row) }
    end

    private

    def band_cards
      scope = @band.band_cards.includes(magic_card: :boxset)
      @done ? scope.done.order(handled_at: :desc, id: :desc).limit(DONE_LIMIT) : scope.to_do
    end

    def collection_ids
      CollectionStats::Scope.call(username: @band.user.username, viewer: @band.user,
                                  collection_id: @band.collection_id)[:collection_ids]
    end

    # { [magic_card_id, finish] => [{ name:, copies: }, ...] }, collections in name order
    def places_for(cards)
      return {} if cards.empty?

      CollectionMagicCard.joins(:collection)
                         .where(collection_id: collection_ids, magic_card_id: cards.map(&:magic_card_id).uniq,
                                staged: false, needed: false)
                         .order('collections.name')
                         .pluck(:magic_card_id, 'collections.name', :quantity, :foil_quantity)
                         .each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |(id, name, qty, foil), places|
        places[[id, 'normal']] << { name: name, copies: qty } if qty.to_i.positive?
        places[[id, 'foil']] << { name: name, copies: foil } if foil.to_i.positive?
      end
    end

    def binder_order(row)
      [row[:band_card].moved == 'up' ? 0 : 1, row[:places].first&.dig(:name).to_s.downcase,
       row[:card].name.to_s.downcase]
    end

    # the band card, its printing, and the crossed finish's prices today
    def build_row(band_card, places)
      card = band_card.magic_card
      price, buylist = PRICE.fetch(band_card.finish).map { |column| card.public_send(column) }

      { band_card: band_card, card: card, price: price, buylist: buylist, places: places }
    end
  end
end
