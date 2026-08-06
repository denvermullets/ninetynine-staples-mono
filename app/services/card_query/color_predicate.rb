#
# builds the WHERE fragment for a color or color-identity term
#
# Colors are a set, so the operators mean set relations rather than comparisons - `c:wu` is
# "contains at least white and blue", `c<=wu` is "uses nothing outside white and blue".
# Everything is composed from two primitives so we never have to aggregate the whole
# magic_cards table:
#
#   contains_all - IN (...) over the color join, grouped and counted, hits the color_id index
#   subset_of    - a correlated NOT EXISTS, hits the magic_card_id index
#
# Colorless is the absence of join rows, not a color row of its own, so it can't be handled
# by equality - `c:c` becomes "has no rows in the join table".
#
# Returns an array ready to splat into `where`: [sql, *binds]. The join table name comes
# from FieldRegistry and is never user input; the color letters are always bound.
#
module CardQuery
  class ColorPredicate < Service
    LETTERS = %w[W U B R G].freeze

    COLORLESS = 'C'.freeze

    VALID = (LETTERS + [COLORLESS]).to_set.freeze

    NAMES = {
      'white' => 'W', 'blue' => 'U', 'black' => 'B', 'red' => 'R', 'green' => 'G',
      'colorless' => COLORLESS
    }.freeze

    # "wu", "w/u", "WU", "white" and "w,u" all mean the same thing
    def self.letters(value)
      raw = value.to_s.downcase.strip
      return [NAMES[raw]] if NAMES.key?(raw)

      raw.gsub(%r{[/,\s]}, '').chars.map(&:upcase).uniq
    end

    def initialize(operator:, value:, join_table:)
      @operator = operator
      @join_table = join_table
      @letters = self.class.letters(value)
    end

    def call
      return colorless_predicate if colorless?

      case @operator
      when '<=' then subset_of
      when '=' then both(contains_all, subset_of)
      when '>' then both(contains_all, negate(subset_of))
      when '<' then both(subset_of, negate(contains_all))
      when '!=' then negate(both(contains_all, subset_of))
      else contains_all # `:` and `>=` both mean "contains at least these"
      end
    end

    private

    # a lone "c" means colorless; mixed in with real colors it's noise, so drop it
    def colorless?
      @letters == [COLORLESS]
    end

    def colors
      @colors ||= @letters - [COLORLESS]
    end

    def colorless_predicate
      sql = "NOT EXISTS (SELECT 1 FROM #{@join_table} WHERE #{@join_table}.magic_card_id = magic_cards.id)"

      @operator == '!=' ? negate([sql]) : [sql]
    end

    def contains_all
      [
        "magic_cards.id IN (
           SELECT #{@join_table}.magic_card_id FROM #{@join_table}
           INNER JOIN colors ON colors.id = #{@join_table}.color_id
           WHERE colors.name IN (?)
           GROUP BY #{@join_table}.magic_card_id
           HAVING COUNT(DISTINCT colors.name) = ?
         )".squish,
        colors,
        colors.size
      ]
    end

    # cards with no colors at all satisfy this, which matches Scryfall - c<=wu includes
    # colorless cards
    def subset_of
      [
        "NOT EXISTS (
           SELECT 1 FROM #{@join_table}
           INNER JOIN colors ON colors.id = #{@join_table}.color_id
           WHERE #{@join_table}.magic_card_id = magic_cards.id AND colors.name NOT IN (?)
         )".squish,
        colors
      ]
    end

    def both(left, right)
      ["(#{left.first}) AND (#{right.first})", *left.drop(1), *right.drop(1)]
    end

    def negate(predicate)
      ["NOT (#{predicate.first})", *predicate.drop(1)]
    end
  end
end
