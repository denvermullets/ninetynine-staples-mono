# Which printing stands for a card when a lookup names the card but not a printing - an oracle id, a
# name search, a token by what it does
module CanonicalPrinting
  extend ActiveSupport::Concern

  # Scryfall's stand-in for art that is not out yet, stored in the image columns like a real image
  PLACEHOLDER_IMAGE = 'errors.scryfall.com/soon.jpg'.freeze

  # Promo and memorabilia sets (gold borders, art series) are the printings least like the card as
  # it is played, so they lose to any regular printing.
  OFF_BEAT_SET_TYPES = %w[promo memorabilia].freeze

  # How a lookup that names a card but not a printing (by oracle id, by name) picks one: a printing
  # with an image, then one from a regular set, then the newest, then the front face. Each test is
  # wrapped in COALESCE because DESC sorts NULLs first.
  CANONICAL_PRINTING_ORDER = <<~SQL.squish.freeze
    COALESCE(magic_cards.image_medium <> '' AND magic_cards.image_medium NOT LIKE '%#{PLACEHOLDER_IMAGE}%', false) DESC,
    COALESCE(boxsets.set_type NOT IN (#{OFF_BEAT_SET_TYPES.map { |type| "'#{type}'" }.join(', ')}), true) DESC,
    boxsets.release_date DESC NULLS LAST,
    magic_cards.card_side ASC NULLS FIRST,
    magic_cards.id DESC
  SQL

  # What counts as "the same card" for canonical_printings. A card is its oracle id. A token is how it
  # plays - name, power/toughness, colors and text - since sets reprint the same token under new oracle
  # ids, and colors live in a join table, so they join the key as one sorted string.
  SAME_CARD_KEY = 'magic_cards.scryfall_oracle_id'.freeze
  SAME_TOKEN_KEY = <<~SQL.squish.freeze
    magic_cards.name, magic_cards.power, magic_cards.toughness, magic_cards.text,
    (SELECT STRING_AGG(colors.name, '' ORDER BY colors.name) FROM magic_card_colors
       JOIN colors ON colors.id = magic_card_colors.color_id
      WHERE magic_card_colors.magic_card_id = magic_cards.id)
  SQL

  # The canonical printing (CANONICAL_PRINTING_ORDER) of each card - each oracle id, or with
  # `by: :same_token` each SAME_TOKEN_KEY. Returns a fresh relation over those rows, so the caller's own
  # order and pagination apply on top. The key is picked here, from constants, rather than passed in, so
  # no caller's string ever reaches the SQL.
  class_methods do
    def canonical_printings(by: :oracle_id)
      key = case by
            when :oracle_id then SAME_CARD_KEY
            when :same_token then SAME_TOKEN_KEY
            else raise ArgumentError, "unknown canonical key #{by.inspect}"
            end
      ids = left_joins(:boxset).reorder(Arel.sql("#{key}, #{CANONICAL_PRINTING_ORDER}"))
                               .select(Arel.sql("DISTINCT ON (#{key}) magic_cards.id"))
      unscoped.where(id: ids)
    end
  end
end
