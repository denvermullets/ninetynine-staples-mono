#
# handles deduplication of cards by a specified column
# useful for showing unique cards by name across multiple printings
#
module CollectionQuery
  class Deduplicate < Service
    # Allowlist of valid column names to prevent SQL injection
    ALLOWED_COLUMNS = %w[name card_type].freeze
    ALLOWED_PREFER_BY = %w[edhrec_rank edhrec_saltiness normal_price foil_price].freeze

    def initialize(cards:, column: :name, prefer_by: :edhrec_rank, prefer_direction: :asc)
      @cards = cards
      @column = sanitize_column(column)
      @prefer_by = sanitize_prefer_by(prefer_by)
      @prefer_direction = prefer_direction.to_s.downcase == 'desc' ? 'DESC' : 'ASC'
    end

    def call
      return @cards if @column.blank? || @prefer_by.blank?

      # Use DISTINCT ON to get one record per unique column value
      # Order by the column first (required for DISTINCT ON), then by preference
      subquery = @cards
                 .select("DISTINCT ON (magic_cards.#{@column}) magic_cards.id")
                 .order(Arel.sql("magic_cards.#{@column}, magic_cards.#{@prefer_by} #{@prefer_direction} NULLS LAST"))

      MagicCard.where(id: subquery)
               .includes(:boxset, :finishes, magic_card_color_idents: :color)
    end

    private

    def sanitize_column(column)
      col = column.to_s
      ALLOWED_COLUMNS.include?(col) ? col : nil
    end

    def sanitize_prefer_by(prefer_by)
      col = prefer_by.to_s
      ALLOWED_PREFER_BY.include?(col) ? col : nil
    end
  end
end
