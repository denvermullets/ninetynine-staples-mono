#
# handles filtering on a collection
#
module CollectionQuery
  class Filter < Service
    def initialize(cards:, **options)
      @cards = cards
      @boxset_id = options[:code] ? Boxset.find_by(code: options[:code])&.id : nil
      @collection_id = options[:collection_id]
      @exact_color_match = options[:exact_color_match] || false

      # Support both direct values and raw params
      if options[:params]
        parse_from_params(options[:params])
      else
        @rarities = options[:rarities]&.compact_blank
        @colors = options[:colors]&.compact_blank
        @price_change_min = options[:price_change_min]
        @price_change_max = options[:price_change_max]
      end
    end

    def call
      filtered = @cards
      filtered = filtered.where(collections: { id: @collection_id }) if @collection_id.present?
      filtered = filtered.where(boxset_id: @boxset_id) if @boxset_id.present?
      filtered = filtered.where(rarity: @rarities) if @rarities.present?
      filtered = filter_by_price_change(filtered) if @price_change_min.present? || @price_change_max.present?
      filtered = filter_by_colors(filtered) if @colors.present?

      filtered
    end

    private

    def parse_from_params(params)
      @rarities = params[:rarity]&.flat_map { |r| r.split(',') }&.compact_blank
      @colors = params[:mana]&.flat_map { |c| c.split(',') }&.compact_blank
      @price_change_min, @price_change_max = parse_price_change_range(params[:price_change_range])
    end

    def parse_price_change_range(range)
      return [nil, nil] if range.blank?

      min, max = range.split(',').map(&:to_f)
      [min, max]
    end

    def filter_by_price_change(cards)
      return cards unless @price_change_min.present? || @price_change_max.present?

      # Show cards where EITHER normal or foil price change falls within the range
      if @price_change_min.present? && @price_change_max.present?
        cards.where(
          '(price_change_weekly_normal BETWEEN ? AND ?) OR (price_change_weekly_foil BETWEEN ? AND ?)',
          @price_change_min, @price_change_max, @price_change_min, @price_change_max
        )
      elsif @price_change_min.present?
        cards.where('price_change_weekly_normal >= ? OR price_change_weekly_foil >= ?',
                    @price_change_min, @price_change_min)
      else
        cards.where('price_change_weekly_normal <= ? OR price_change_weekly_foil <= ?',
                    @price_change_max, @price_change_max)
      end
    end

    def filter_by_colors(cards)
      # if "C" (colorless) is selected, ONLY include colorless cards (no colors)
      if @colors.include?('C')
        return cards.left_joins(:magic_card_colors)
                    .where(magic_card_colors: { id: nil })
      end

      if @exact_color_match
        filter_by_exact_colors(cards)
      else
        filter_by_any_colors(cards)
      end
    end

    def filter_by_any_colors(cards)
      cards.joins(magic_card_colors: :color)
           .where(colors: { name: @colors })
           .distinct
    end

    def filter_by_exact_colors(cards)
      selected = @colors.uniq.sort

      # Find cards that have exactly the selected colors (no more, no less)
      cards.where(
        id: MagicCard.joins(magic_card_colors: :color)
                    .group('magic_cards.id')
                    .having('ARRAY_AGG(colors.name ORDER BY colors.name) = ARRAY[?]::varchar[]', selected)
                    .select(:id)
      )
    end
  end
end
