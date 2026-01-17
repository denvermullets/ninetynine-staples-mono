#
# handles sort configuration, validation, and link param generation
#
module CollectionQuery
  class SortConfig
    attr_reader :column, :direction

    VALID_DIRECTIONS = %w[asc desc].freeze
    DEFAULT_DIRECTION = 'asc'.freeze

    def initialize(params:, allowed_columns:, default_column: nil, preserve_params: [])
      @params = params
      @allowed_columns = allowed_columns.map(&:to_s)
      @default_column = default_column || @allowed_columns.first
      @preserve_params = preserve_params

      @column = validate_column
      @direction = validate_direction
    end

    # Generate params for sort links in views
    def link_params(for_column)
      base_params = preserved_params
      base_params[:sort] = for_column.to_s
      base_params[:direction] = toggle_direction_for(for_column)
      base_params.compact_blank
    end

    # Check if a column is currently being sorted
    def sorting?(col)
      @column == col.to_s
    end

    # Get sort indicator for views
    def indicator(col)
      return nil unless sorting?(col)

      @direction == 'asc' ? '▲' : '▼'
    end

    private

    def validate_column
      @allowed_columns.include?(@params[:sort].to_s) ? @params[:sort].to_s : @default_column
    end

    def validate_direction
      VALID_DIRECTIONS.include?(@params[:direction].to_s) ? @params[:direction].to_s : DEFAULT_DIRECTION
    end

    def toggle_direction_for(for_column)
      if @column == for_column.to_s && @direction == 'asc'
        'desc'
      else
        'asc'
      end
    end

    def preserved_params
      @preserve_params.each_with_object({}) do |key, hash|
        value = @params[key]
        hash[key] = value if value.present?
      end
    end
  end
end
