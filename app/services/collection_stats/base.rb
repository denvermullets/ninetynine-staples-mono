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

    # `owned` is one row per printing; card_roles is one row per *card*, keyed by oracle id. Joining
    # roles straight onto `owned` would count a card held in five printings five times, so this
    # rolls copies and value up to the oracle id first and roles join against that instead.
    #
    # The cast sits on the magic_cards side (uuid) rather than the card_roles side (string) on
    # purpose: casting the card_roles column would make index_card_roles_on_scryfall_oracle_id
    # unusable and turn every role lookup into a sequential scan of the table.
    #
    # Printings with no oracle id stay in. They can never match a role, but they are still cards
    # somebody owns and they belong in the coverage denominator.
    def owned_by_oracle_rows
      MagicCard
        .joins('JOIN owned ON owned.magic_card_id = magic_cards.id')
        .group('magic_cards.scryfall_oracle_id')
        .select(<<~SQL.squish)
          magic_cards.scryfall_oracle_id::text AS scryfall_oracle_id,
          SUM(#{TOTAL_QTY}) AS copies,
          SUM(#{REAL_VALUE}) AS value,
          COUNT(*) AS printings
        SQL
    end

    # Both CTEs, in order: owned_by_oracle is written against `owned` and cannot be declared
    # without it. FROM is the CTE rather than magic_cards - the printings are already rolled up.
    def owned_oracles
      MagicCard
        .with(owned: owned_rows, owned_by_oracle: owned_by_oracle_rows)
        .from('owned_by_oracle')
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
