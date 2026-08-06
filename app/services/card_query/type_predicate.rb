#
# builds the WHERE fragment for a `t:` term
#
# A type line is spread across three tables - "Legendary Creature - Elf Druid" is a
# super_type, a card_type and two sub_types - and `t:` doesn't care which one it hits, so
# each word is matched against all three.
#
# Words are matched independently rather than as one string, because a multi-word type
# never lives in a single row: `t:"legendary creature"` has to find "Legendary" in
# super_types and "Creature" in card_types. Every word must match somewhere.
#
# Each table is an IN subquery, so the three-way OR can't fan the rows out and inflate the
# aggregates the collections table selects. Returns [sql, *binds] to splat into `where`.
#
module CardQuery
  class TypePredicate < Service
    TABLES = [
      { join_table: 'magic_card_types', lookup_table: 'card_types', fk: 'card_type_id' },
      { join_table: 'magic_card_sub_types', lookup_table: 'sub_types', fk: 'sub_type_id' },
      { join_table: 'magic_card_super_types', lookup_table: 'super_types', fk: 'super_type_id' }
    ].freeze

    EXACT_OPS = %w[= !=].freeze

    def initialize(operator:, value:)
      @operator = operator
      @words = value.to_s.split
    end

    def call
      return nil if @words.empty?

      clauses = @words.map { |word| word_clause(word) }
      predicate = ["(#{clauses.map(&:first).join(') AND (')})", *clauses.flat_map { |clause| clause.drop(1) }]

      @operator == '!=' ? ["NOT COALESCE((#{predicate.first}), FALSE)", *predicate.drop(1)] : predicate
    end

    private

    # `=` pins the whole type name, `:` matches part of it the way a type line search would
    def exact?
      EXACT_OPS.include?(@operator)
    end

    def word_clause(word)
      value = exact? ? word : "%#{ActiveRecord::Base.sanitize_sql_like(word)}%"

      [TABLES.map { |table| subquery(table) }.join(' OR '), *Array.new(TABLES.size, value)]
    end

    def subquery(table)
      match = if exact?
                "LOWER(#{table[:lookup_table]}.name) = LOWER(?)"
              else
                "#{table[:lookup_table]}.name ILIKE ?"
              end

      "magic_cards.id IN (
         SELECT #{table[:join_table]}.magic_card_id FROM #{table[:join_table]}
         INNER JOIN #{table[:lookup_table]} ON #{table[:lookup_table]}.id = #{table[:join_table]}.#{table[:fk]}
         WHERE #{match}
       )".squish
    end
  end
end
