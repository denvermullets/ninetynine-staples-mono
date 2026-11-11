module Collections
  # -> { collection_id => "WUB" }, one grouped query for a whole page of deck cards.
  #
  # A deck with a commander takes the commanders' identity - that is the deck's identity by the rules,
  # and the mainboard may still hold off-colour cards mid-build. A deck without one falls back to the
  # union of its mainboard. Sideboards never count. "C" is a deck whose cards are all colourless; a
  # deck with no cards at all is left out, so the card shows nothing rather than claiming colourless.
  class ColorIdentities < Service
    COLOR_JOINS = <<~SQL.squish.freeze
      LEFT JOIN magic_card_color_idents ON magic_card_color_idents.magic_card_id = collection_magic_cards.magic_card_id
      LEFT JOIN colors ON colors.id = magic_card_color_idents.color_id
    SQL

    COMMANDER_MASK = "COALESCE(BIT_OR(#{Commanders::ColorMask::BIT_CASE}) " \
                     "FILTER (WHERE collection_magic_cards.board_type = 'commander'), 0)".freeze

    HAS_COMMANDER = "BOOL_OR(collection_magic_cards.board_type = 'commander')".freeze

    def initialize(collections:)
      @collection_ids = collections.map(&:id)
    end

    def call
      return {} if @collection_ids.empty?

      rows.to_h do |collection_id, has_commander, commander_mask, deck_mask|
        [collection_id, Commanders::ColorMask.letters(has_commander ? commander_mask : deck_mask)]
      end
    end

    private

    def rows
      CollectionMagicCard
        .where(collection_id: @collection_ids)
        .where(board_type: ['mainboard', 'commander', nil])
        .joins(COLOR_JOINS)
        .group(:collection_id)
        .pluck(:collection_id, Arel.sql(HAS_COMMANDER), Arel.sql(COMMANDER_MASK),
               Arel.sql(Commanders::ColorMask::IDENTITY_MASK))
    end
  end
end
