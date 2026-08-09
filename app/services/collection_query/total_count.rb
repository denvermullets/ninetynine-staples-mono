#
# scalar total for the grouped collection relation
#
# Search::Collection groups by magic_cards.id, so ActiveRecord's count(:all) hands back a Hash with
# one entry per card - the whole result set off the wire and a matching Ruby hash built just to
# render "of 19,995". COUNT(*) OVER () asks Postgres for the same number and returns a single row.
#
# Derived from the relation it's handed rather than rebuilt from scratch, so any filter added to
# CollectionQuery::Filter or CardQuery::Builder later is counted without touching this class.
#
module CollectionQuery
  class TotalCount < Service
    def initialize(cards:)
      @cards = cards
    end

    def call
      return @cards.size if @cards.is_a?(Array)
      return @cards.count unless @cards.respond_to?(:group_values) && @cards.group_values.present?

      # unscope(:order) - sorting 20k grouped rows to count them is pure overhead, and pick
      # replaces the select list, so nothing the ORDER BY might lean on survives anyway.
      # pick returns nil when nothing matches.
      @cards.unscope(:order).pick(Arel.sql('COUNT(*) OVER ()')).to_i
    end
  end
end
