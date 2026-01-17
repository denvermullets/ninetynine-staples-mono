#
# handles column-based sorting with direction
# works with any ActiveRecord relation
#
module CollectionQuery
  class ColumnSort < Service
    NUMERIC_COLUMNS = %w[edhrec_rank edhrec_saltiness mana_value normal_price foil_price].freeze
    # Allowlist of valid column names to prevent SQL injection
    ALLOWED_COLUMNS = %w[
      name card_type mana_value edhrec_rank edhrec_saltiness
      normal_price foil_price release_date code deck_type
    ].freeze

    def initialize(records:, column:, direction: 'asc', table_name: nil)
      @records = records
      @column = sanitize_column(column)
      @direction = direction.to_s.downcase == 'desc' ? 'DESC' : 'ASC'
      @table_name = sanitize_table_name(table_name)
    end

    # Backwards compatible alias
    def self.call(cards: nil, records: nil, **)
      new(records: records || cards, **).call
    end

    def call
      return @records if @column.blank?

      if numeric_column?
        sort_with_nulls_last
      else
        sort_standard
      end
    end

    private

    def sanitize_column(column)
      col = column.to_s
      ALLOWED_COLUMNS.include?(col) ? col : nil
    end

    def sanitize_table_name(table_name)
      return nil if table_name.blank?

      # Only allow alphanumeric and underscore for table names
      table_name.to_s.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*\z/) ? table_name.to_s : nil
    end

    def numeric_column?
      NUMERIC_COLUMNS.include?(@column)
    end

    def qualified_column
      @table_name ? "#{@table_name}.#{@column}" : @column
    end

    def sort_with_nulls_last
      @records.order(Arel.sql("#{qualified_column} #{@direction} NULLS LAST"))
    end

    def sort_standard
      @records.order("#{qualified_column} #{@direction}")
    end
  end
end
