#
# handles deduplication of cards by a specified column
# useful for showing unique cards by name across multiple printings
#
module CollectionQuery
  class Deduplicate < Service
    def initialize(cards:, column: :name, prefer_by: :edhrec_rank, prefer_direction: :asc)
      @cards = cards
      @column = column.to_s
      @prefer_by = prefer_by.to_s
      @prefer_direction = prefer_direction.to_s.downcase == 'desc' ? 'DESC' : 'ASC'
    end

    def call
      return @cards if @column.blank?

      # Use DISTINCT ON to get one record per unique column value
      # Order by the column first (required for DISTINCT ON), then by preference
      subquery = @cards
                 .select("DISTINCT ON (magic_cards.#{@column}) magic_cards.id")
                 .order(Arel.sql("magic_cards.#{@column}, magic_cards.#{@prefer_by} #{@prefer_direction} NULLS LAST"))

      MagicCard.where(id: subquery)
               .includes(:boxset, :finishes, magic_card_color_idents: :color)
    end
  end
end
