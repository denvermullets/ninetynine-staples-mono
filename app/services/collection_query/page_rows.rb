#
# fetches one page of the collections table without sorting full magic_cards rows
#
# The relation orders on ::Search::Collection::OWNED_PRICE_SQL, an aggregate no index can satisfy -
# Postgres has to aggregate every owned row before it can pick 50. That part is unavoidable, but
# pushing 1.2 KB-wide magic_cards.* rows through the sort spilled it to disk. Narrowing the SELECT
# to the id plus the two quantity aggregates keeps it in a top-N heapsort; the 50 full rows are
# then fetched by id.
#
# The aggregates ride along on the second query through unnest(...) WITH ORDINALITY rather than
# being recomputed - recomputing would mean duplicating the user and collection scoping the
# pipeline already applied - and the ordinality column carries the page order in SQL, so there is
# no Ruby re-sort to get out of step with the ORDER BY.
#
module CollectionQuery
  class PageRows < Service
    def initialize(cards:, preloads: [])
      @cards = cards
      @preloads = preloads
    end

    def call
      return with_preloads(@cards).to_a unless deferrable?

      rows = @cards.reselect(narrow_select).to_a
      return [] if rows.empty?

      hydrate(rows)
    end

    private

    # CardQuery::Builder and CollectionQuery::Filter hang HAVING off the aggregates, so an
    # ungrouped relation is not the collections relation - load it as-is rather than guessing
    # at a narrow select for it
    def deferrable?
      @cards.respond_to?(:group_values) && @cards.group_values.present?
    end

    def narrow_select
      Arel.sql(
        "magic_cards.id AS id, #{::Search::Collection::QUANTITY_SQL} AS quantity, " \
        "#{::Search::Collection::FOIL_QUANTITY_SQL} AS foil_quantity"
      )
    end

    # quantity/foil_quantity come back as real attributes here, which is what the table view's
    # card.respond_to?(:foil_quantity) checks read to decide which price columns to render
    def hydrate(rows)
      with_preloads(
        MagicCard
          .joins(ordinality_join(rows))
          .select('magic_cards.*, owned.quantity, owned.foil_quantity')
          .order(Arel.sql('owned.ord'))
      ).to_a
    end

    # preload raises on an empty splat, and callers that want no associations pass none
    def with_preloads(relation)
      @preloads.empty? ? relation : relation.preload(*@preloads)
    end

    def ordinality_join(rows)
      ActiveRecord::Base.sanitize_sql_array(
        ['JOIN unnest(ARRAY[?]::bigint[], ARRAY[?]::bigint[], ARRAY[?]::bigint[]) WITH ORDINALITY ' \
         'AS owned(id, quantity, foil_quantity, ord) ON owned.id = magic_cards.id',
         rows.map(&:id), rows.map { |row| row.quantity.to_i }, rows.map { |row| row.foil_quantity.to_i }]
      )
    end
  end
end
