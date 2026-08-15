module Commanders
  # Colour identity as a 5-bit integer, so a collection can be profiled once per identity rather
  # than scored once per commander.
  #
  # There are exactly 5 rows in `colors`, so there are exactly 32 possible identities. That is the
  # whole trick behind the buildability profile: instead of measuring 3,235 commanders against a
  # 20k-row collection, the collection is bucketed into 32 groups once, and a commander's legal pool
  # is the sum over the submasks of its own identity - a 32-entry lookup rather than a scan.
  #
  # THE BITS ARE KEYED ON colors.name, NEVER ON colors.id. The rows are seeded W=1, G=2, U=3, B=4,
  # R=5 - not WUBRG order - so keying on id silently swaps green and blue and every mask involving
  # either colour comes out wrong in a way nothing else in the app would notice.
  # CardQuery::ColorPredicate joins on colors.name for the same reason.
  class ColorMask
    BITS = { 'W' => 1, 'U' => 2, 'B' => 4, 'R' => 8, 'G' => 16 }.freeze

    # Colourless is mask 0, and it is a real bucket rather than a missing one: a card with no colour
    # identity has no magic_card_color_idents rows at all, and it is legal in every deck.
    COLORLESS = 0

    ALL = BITS.values.sum

    MASKS = (COLORLESS..ALL).to_a.freeze

    # The CASE that turns a joined colors row into its bit, for BIT_OR to aggregate. Written from
    # BITS so the SQL and the Ruby cannot disagree about which colour is which.
    def self.bit_case(colors_alias = 'colors')
      whens = BITS.map { |letter, bit| "WHEN '#{letter}' THEN #{bit}" }.join(' ')

      "CASE #{colors_alias}.name #{whens} END"
    end

    # Every mask that fits inside this one, itself and colourless included. A Jund commander can play
    # mono-red, Rakdos and colourless cards, so its pool is the sum of all eight of those buckets.
    def self.submasks(mask)
      MASKS.select { |candidate| candidate & mask == candidate }
    end

    # -> Integer. One card's identity, for callers holding a MagicCard rather than a query result.
    def self.for(magic_card)
      names = MagicCardColorIdent.where(magic_card_id: magic_card.id)
                                 .joins(:color)
                                 .pluck('colors.name')

      names.sum { |name| BITS.fetch(name, 0) }
    end

    # -> "BRG", or "C" for colourless. The order is BITS' order, which is WUBRG.
    def self.letters(mask)
      return 'C' if mask == COLORLESS

      BITS.filter_map { |letter, bit| letter if mask & bit == bit }.join
    end
  end
end
