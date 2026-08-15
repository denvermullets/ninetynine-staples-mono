#
# builds the HAVING fragments for the ownership terms - qty:, foil:, proxy:, needed:
#
# These are the exception to Builder's "everything is an IN / EXISTS subquery" rule. The relation is
# already grouped by magic_cards.id with SUM(...) aggregates in its SELECT (Search::Collection#sort_cards),
# so ownership is asked as a HAVING over aggregates that are already there rather than a fresh join -
# joining again would fan the rows out and inflate the very sums being filtered on.
#
# That also means they only mean anything on a grouped relation; Builder#apply_having guards for it.
#
# Returns an array ready to splat into `having`: [sql, *binds]. Column names come from FieldRegistry
# and are never user input.
#
module CardQuery
  class OwnedPredicate < Service
    TOTAL = 'SUM(COALESCE(collection_magic_cards.quantity, 0)) + ' \
            'SUM(COALESCE(collection_magic_cards.foil_quantity, 0))'.freeze

    def initialize(handler:, operator:, value:, columns: nil)
      @handler = handler
      @operator = operator
      @value = value
      @columns = columns
    end

    def call
      case @handler
      when :owned_qty then quantity
      when :owned_flag then flag
      else needed
      end
    end

    private

    def quantity
      ["#{TOTAL} #{@operator} ?", @value.to_i]
    end

    def flag
      sums = @columns.map { |column| "SUM(COALESCE(collection_magic_cards.#{column}, 0))" }.join(' + ')

      [truthy? ? "#{sums} > 0" : "#{sums} = 0"]
    end

    # needed is a per-row boolean, so it has to be aggregated to survive the GROUP BY
    def needed
      ['COALESCE(BOOL_OR(collection_magic_cards.needed), FALSE) = ?', truthy?]
    end

    def truthy?
      %w[true yes].include?(@value.to_s.downcase)
    end
  end
end
