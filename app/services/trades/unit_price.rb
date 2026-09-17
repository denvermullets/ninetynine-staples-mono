# The two unit prices a finish-aware total needs, with the fallback rules from
# CollectionMagicCard#display_unit_price: a price of zero means "we have no number for this finish",
# not "this finish is worthless", so each finish falls back to the other.
#
# A foil with no foil price is worth the regular price (and a card priced only as a foil values its
# regular copies at the foil price, the same way MagicCard#display_price does). Without that a
# foil-only printing whose foil price hasn't been ingested yet would value a side of a trade at $0.
#
# Everything is BigDecimal - to_d treats nil as zero and keeps money out of floats.
module Trades
  module UnitPrice
    # [regular, foil], each falling back to the other when its own price is missing
    def self.pair(normal, foil)
      normal = normal.to_d
      foil = foil.to_d

      [normal.positive? ? normal : foil, foil.positive? ? foil : normal]
    end

    def self.value(quantity:, foil_quantity:, normal:, foil:)
      regular_price, foil_price = pair(normal, foil)

      (quantity.to_i * regular_price) + (foil_quantity.to_i * foil_price)
    end
  end
end
