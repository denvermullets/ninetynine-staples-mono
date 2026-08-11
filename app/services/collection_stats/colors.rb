# Colour identity breakdown - copies and value per colour.
#
# The join table cannot be aggregated directly. A Golgari card has TWO
# magic_card_color_idents rows, so "JOIN ... GROUP BY colors.name" counts its copies and its
# dollars once under Black and again under Green, and the panel reports more value than the
# collection holds. The card_colors CTE rolls the join table up to one row per card FIRST,
# and only then does the outer query bucket it, so every card lands in exactly one label.
#
# COUNT(*) + MIN(colors.name) is the whole roll-up: the count decides mono vs multi, and the
# MIN is the letter - meaningful only when the count is 1, which is the only case that reads it.
#
# Written against the join tables rather than MagicCard#colors because that association is
# declared twice (through magic_card_colors, then through magic_card_color_idents) and the
# second silently wins. Reaching through it would make this panel depend on a bug staying put.
# The upside is that Collections::GroupCards#group_by_color calls that same shadowed
# association, so the collection page is already grouping by colour identity - this panel
# agrees with it rather than offering a second, different answer.
module CollectionStats
  class Colors < Base
    ORDER = Collections::GroupCards::COLOR_ORDER
    COLORLESS = 'Colorless'.freeze
    MULTICOLOR = 'Multicolor'.freeze

    # colors.name holds MTGJSON's single letters, not display names -
    # CardIngestion::AttributeCreator#create_color_identities writes the raw colorIdentity
    # array straight through.
    NAMES = { 'W' => 'White', 'U' => 'Blue', 'B' => 'Black', 'R' => 'Red', 'G' => 'Green' }.freeze

    # mana-font has no multicolour glyph, which is why admin/game_changers/_color_icon falls
    # back to an inline SVG for that case. Nil here, and the legend renders the swatch alone.
    SWATCHES = { 'White' => 'ms-w', 'Blue' => 'ms-u', 'Black' => 'ms-b', 'Red' => 'ms-r',
                 'Green' => 'ms-g', COLORLESS => 'ms-c', MULTICOLOR => nil }.freeze

    CARD_COLORS = <<~SQL.squish.freeze
      SELECT magic_card_color_idents.magic_card_id AS magic_card_id,
             COUNT(*) AS ident_count,
             MIN(colors.name) AS solo_color
      FROM magic_card_color_idents
      JOIN colors ON colors.id = magic_card_color_idents.color_id
      JOIN owned ON owned.magic_card_id = magic_card_color_idents.magic_card_id
      GROUP BY magic_card_color_idents.magic_card_id
    SQL

    BUCKET = <<~SQL.squish.freeze
      CASE WHEN COALESCE(card_colors.ident_count, 0) = 0 THEN '#{COLORLESS}'
           WHEN card_colors.ident_count > 1 THEN '#{MULTICOLOR}'
           ELSE card_colors.solo_color END
    SQL

    def call
      return [] if no_collections?

      rows = fetch
      total = rows.sum { |row| row[:copies] }

      rows.sort_by { |row| [ORDER.index(row[:label]) || ORDER.size, row[:label]] }
          .map { |row| row.merge(share: share(row[:copies], total)) }
    end

    private

    # LEFT JOIN, not JOIN: a card with no identity rows at all is Colorless and has to survive
    # the join, not vanish from the totals.
    def fetch
      owned_cards
        .with(card_colors: Arel.sql(CARD_COLORS))
        .joins('LEFT JOIN card_colors ON card_colors.magic_card_id = magic_cards.id')
        .group(Arel.sql(BUCKET))
        .pluck(Arel.sql(BUCKET), Arel.sql("SUM(#{TOTAL_QTY})"), Arel.sql("SUM(#{TOTAL_VALUE})"))
        .map { |bucket, copies, value| build_row(bucket, copies, value) }
        .reject { |row| row[:copies].zero? }
    end

    # an empty slice is a legend entry pointing at nothing, so zero buckets are dropped rather
    # than zero-filled the way ManaCurve fills its curve
    def build_row(bucket, copies, value)
      label = NAMES.fetch(bucket, bucket)

      { label: label, copies: copies.to_i, value: to_money(value || 0),
        swatch: SWATCHES.fetch(label, 'ms-c') }
    end
  end
end
