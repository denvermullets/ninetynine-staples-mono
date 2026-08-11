# Shared query foundation for the collection analytics dashboard.
#
# A printing can sit in several of the viewer's collections at once, so every panel starts from
# the same `owned` CTE: one row per magic_card with the four quantity buckets already summed.
# Joining the taxonomy tables (rarity, colors, card_types, boxsets) against that rolled-up row is
# what stops a card held in three binders from counting its rarity three times.
#
# The scope is deliberately `staged: false, needed: false`, matching Collections::UpdateTotals -
# staged rows are deck-builder scratch and needed rows are wishlist. If this diverged, the
# dashboard totals would not match the stat tiles on the collection page.
module CollectionStats
  class Base < Service
    include CollectionStats::Sql

    def initialize(collection_ids:)
      @collection_ids = Array(collection_ids).compact
    end

    private

    def no_collections?
      @collection_ids.empty?
    end

    def owned_rows
      CollectionMagicCard
        .where(collection_id: @collection_ids, staged: false, needed: false)
        .group(:magic_card_id)
        .select(<<~SQL.squish)
          collection_magic_cards.magic_card_id AS magic_card_id,
          SUM(collection_magic_cards.quantity) AS qty,
          SUM(collection_magic_cards.foil_quantity) AS foil_qty,
          SUM(collection_magic_cards.proxy_quantity) AS proxy_qty,
          SUM(collection_magic_cards.proxy_foil_quantity) AS proxy_foil_qty
        SQL
    end

    def owned_cards
      MagicCard.with(owned: owned_rows).joins('JOIN owned ON owned.magic_card_id = magic_cards.id')
    end

    # fdiv, not /, because these totals are often BigDecimal and BigDecimal division returns a
    # BigDecimal that renders as "0.145e2" the moment it reaches a view
    def share(part, total)
      return 0.0 if total.to_f.zero?

      (part.fdiv(total) * 100).round(1).to_f
    end

    def to_money(value)
      value.to_d.round(2)
    end

    # no ss-grad and no rarity class, unlike the table views: an aggregate row has no rarity, and
    # ss-grad without one renders a gradient with no colour stops. Plain, the glyph inherits
    # currentColor from the label beside it, which is right in both themes.
    def keyrune_icon(keyrune)
      return if keyrune.blank?

      "no-tailwind ss ss-#{keyrune.downcase} ss-fw"
    end
  end
end
