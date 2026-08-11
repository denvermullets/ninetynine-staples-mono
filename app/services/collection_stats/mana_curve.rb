# Mana curve - copies and value at each mana value.
#
# Lands and tokens are excluded or the chart is a wall of MV-0 that hides the actual curve;
# a typical binder is a third lands. There is no is_land column, so lands are found through
# card_types with NOT EXISTS rather than a LEFT JOIN: an "Artifact Creature" has two
# magic_card_types rows and a join would double its copies before the CASE ever ran.
#
# 'X' means mana_value IS NULL, not "costs {X}". Fireball has mana_value 1 and belongs in the
# 1 bucket like every other one-drop - an X spell still costs its non-X pips. That is the same
# meaning DeckBuilder::GroupCards and PreconDecks::GroupCards give the bucket, and the panel
# subtext says so out loud because an X bar on a curve reads as "X spells" to a player.
module CollectionStats
  class ManaCurve < Base
    TOP = 7
    BUCKETS = ((0...TOP).map(&:to_s) + ["#{TOP}+", 'X']).freeze

    NOT_A_LAND = <<~SQL.squish.freeze
      NOT EXISTS (
        SELECT 1 FROM magic_card_types
        JOIN card_types ON card_types.id = magic_card_types.card_type_id
        WHERE magic_card_types.magic_card_id = magic_cards.id
          AND card_types.name = 'Land'
      )
    SQL

    # FLOOR rather than a cast: mana_value is decimal(10,2) and the Un-sets ship halves
    # (Little Girl is 0.5). Postgres rounds numeric to integer half away from zero, so a cast
    # would file a half-mana card one bucket too high; FLOOR matches the deck builder's to_i.
    BUCKET = <<~SQL.squish.freeze
      CASE WHEN magic_cards.mana_value IS NULL THEN 'X'
           WHEN magic_cards.mana_value >= #{TOP} THEN '#{TOP}+'
           ELSE FLOOR(magic_cards.mana_value)::int::text END
    SQL

    def call
      return empty_result if no_collections?

      found = fetch
      { buckets: buckets(found), average: average(found) }
    end

    private

    def empty_result
      { buckets: BUCKETS.map { |label| blank(label) }, average: 0.0 }
    end

    def blank(label)
      { label: label, copies: 0, value: 0 }
    end

    # zero-filled on purpose: a curve with a hole at 3 has to show an empty bar, not close the
    # gap and pretend 2 sits next to 4
    # mv_copies is scaffolding for the average and never reaches the view
    def buckets(found)
      BUCKETS.map { |label| found[label]&.except(:mv_copies) || blank(label) }
    end

    # rides along on the same grouped scan as a fourth aggregate, so the footer costs no query.
    # X is left out - a card with no recorded mana value cannot pull the average anywhere.
    def average(found)
      spells = found.values.reject { |row| row[:label] == 'X' }
      copies = spells.sum { |row| row[:copies] }
      return 0.0 if copies.zero?

      spells.sum { |row| row[:mv_copies] }.fdiv(copies).round(2).to_f
    end

    def fetch
      owned_cards
        .where(magic_cards: { is_token: false })
        .where(NOT_A_LAND)
        .group(Arel.sql(BUCKET))
        .pluck(Arel.sql(BUCKET), Arel.sql("SUM(#{TOTAL_QTY})"), Arel.sql("SUM(#{REAL_VALUE})"),
               Arel.sql("SUM(COALESCE(magic_cards.mana_value, 0) * #{TOTAL_QTY})"))
        .to_h { |label, copies, value, mv| [label, row(label, copies, value, mv)] }
    end

    def row(label, copies, value, mv_copies)
      { label: label, copies: copies.to_i, value: to_money(value || 0),
        mv_copies: mv_copies.to_d }
    end
  end
end
