# A user's want list as the want list page shows it: one row per want, with the copies of it already
# sitting in `collection_ids` counted alongside, so a want that has since been bought is obvious.
#
# "Owned" follows the want, not just the card: an any-printing want is met by any printing sharing
# its oracle id, and a foil-only want is not met by a non-foil copy. Staged and needed rows are left
# out the same way MagicCard#user_owned_copies leaves them out, and proxies never count.
module WantList
  class List < Service
    FILTERS = %w[all any_printing specific owned].freeze

    # price is the finish the want asks for - a foil-only want is sorted by its foil price
    PRICE_SQL = "CASE WHEN want_list_items.foil_preference = 'foil' THEN magic_cards.foil_price " \
                'ELSE COALESCE(NULLIF(magic_cards.normal_price, 0), magic_cards.foil_price) END'.freeze

    # Copies that would satisfy the want, in the finish it asks for. Correlated against
    # want_list_items; wants always point at a front face, which is also where copies are held.
    # :collection_ids is bound by `bind` - an empty list binds as IN (NULL) and owns nothing.
    OWNED_SQL = <<~SQL.squish.freeze
      SELECT COALESCE(SUM(
        CASE want_list_items.foil_preference
          WHEN 'foil' THEN COALESCE(owned_copies.foil_quantity, 0)
          WHEN 'non_foil' THEN COALESCE(owned_copies.quantity, 0)
          ELSE COALESCE(owned_copies.quantity, 0) + COALESCE(owned_copies.foil_quantity, 0)
        END), 0)
      FROM collection_magic_cards owned_copies
      INNER JOIN magic_cards owned_cards ON owned_cards.id = owned_copies.magic_card_id
      WHERE owned_copies.collection_id IN (:collection_ids)
        AND owned_copies.staged = FALSE
        AND owned_copies.needed = FALSE
        AND (
          owned_copies.magic_card_id = want_list_items.magic_card_id
          OR (want_list_items.any_printing
              AND want_list_items.scryfall_oracle_id IS NOT NULL
              AND owned_cards.scryfall_oracle_id = want_list_items.scryfall_oracle_id)
        )
    SQL

    SORTS = {
      'name' => 'magic_cards.name ASC, want_list_items.id ASC',
      'price' => "#{PRICE_SQL} DESC NULLS LAST, magic_cards.name ASC",
      'added' => 'want_list_items.created_at DESC, want_list_items.id DESC'
    }.freeze

    def initialize(user:, collection_ids: [], filter: 'all', sort: 'name')
      @user = user
      @collection_ids = collection_ids
      @filter = FILTERS.include?(filter) ? filter : 'all'
      @sort = SORTS.key?(sort) ? sort : 'name'
    end

    def call
      { items: items, counts: counts }
    end

    private

    def base
      @user.want_list_items.joins(:magic_card)
    end

    def items
      filtered.select('want_list_items.*', bind("(#{OWNED_SQL}) AS owned_quantity"))
              .includes(magic_card: :boxset)
              .order(Arel.sql(SORTS[@sort]))
    end

    def filtered
      case @filter
      when 'any_printing' then base.any_printing
      when 'specific' then base.specific_printing
      when 'owned' then base.where(bind("(#{OWNED_SQL}) > 0"))
      else base
      end
    end

    # the pills, counted with no filter applied so each says what clicking it would list
    def counts
      all, any_printing, owned = base.pick(
        Arel.sql('COUNT(*)'),
        Arel.sql('COUNT(*) FILTER (WHERE want_list_items.any_printing)'),
        Arel.sql(bind("COUNT(*) FILTER (WHERE (#{OWNED_SQL}) > 0)"))
      )

      { all: all.to_i, any_printing: any_printing.to_i, specific: all.to_i - any_printing.to_i,
        owned: owned.to_i }
    end

    def bind(sql)
      WantListItem.sanitize_sql_array([sql, { collection_ids: @collection_ids.map(&:to_i) }])
    end
  end
end
