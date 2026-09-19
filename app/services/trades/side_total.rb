# Retail and buylist totals for a pile of copies at today's prices.
#
# Takes (magic_card_id, quantity, foil_quantity) tuples rather than trade items so the trade builder
# can total a side that has no trade behind it yet. Duplicate printings are summed, so adding the
# same card twice in the builder reads the same as one row holding both copies.
#
# TCG retail is the headline number and the Card Kingdom buylist the floor, the same pair
# CollectionTrades::List#totals shows on the trade list.
module Trades
  class SideTotal < Service
    RETAIL = %i[normal_price foil_price].freeze
    BUYLIST = %i[ck_buylist_normal_price ck_buylist_foil_price].freeze

    def initialize(items:)
      @items = Array(items).map { |item| item.to_h.symbolize_keys }
    end

    def call
      { copies: copies, retail: value(*RETAIL), buylist: value(*BUYLIST) }
    end

    private

    def copies
      quantities.values.sum { |quantity, foil_quantity| quantity + foil_quantity }
    end

    # a printing we can't load prices for contributes nothing rather than blowing up - the builder
    # hands us whatever ids the page posted
    def value(normal_column, foil_column)
      quantities.sum(0.to_d) do |magic_card_id, (quantity, foil_quantity)|
        card = cards[magic_card_id]
        next 0.to_d if card.nil?

        UnitPrice.value(quantity: quantity, foil_quantity: foil_quantity,
                        normal: card[normal_column], foil: card[foil_column])
      end
    end

    def quantities
      @quantities ||= @items.each_with_object({}) do |item, totals|
        id = item[:magic_card_id]
        next if id.blank?

        running = totals[id.to_i] ||= [0, 0]
        running[0] += item[:quantity].to_i
        running[1] += item[:foil_quantity].to_i
      end
    end

    def cards
      @cards ||= MagicCard.where(id: quantities.keys).select(:id, *RETAIL, *BUYLIST).index_by(&:id)
    end
  end
end
