#
# handles filtering on a collection
#
module CollectionQuery
  class Filter < Service
    def initialize(cards:, **options)
      @cards = cards
      @boxset_id = options[:code] ? Boxset.find_by(code: options[:code])&.id : nil
      @collection_id = options[:collection_id]
      @rarities = options[:rarities]&.compact_blank
      @colors = options[:colors]&.compact_blank
      @price_change_min = options[:price_change_min]
      @price_change_max = options[:price_change_max]
      @exact_color_match = options[:exact_color_match] || false
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

    def filter_by_price_change(cards)
      query = cards
      query = query.where('price_change_weekly >= ?', @price_change_min) if @price_change_min.present?
      query = query.where('price_change_weekly <= ?', @price_change_max) if @price_change_max.present?
      query
    end

    def filter_by_colors(cards)
      # if "C" (colorless) is selected, ONLY include colorless cards (no WUBRG)
      if @colors.include?('C')
        return cards.select do |card|
          next if card.mana_cost.nil?

          card.mana_cost.scan(/[WUBRG]/).empty?
        end
      end

      cards.select do |card|
        next if card.mana_cost.nil?

        mana_symbols = card.mana_cost.scan(/[WUBRG]/).uniq.sort
        selected_symbols = @colors.uniq.sort

        if @exact_color_match
          mana_symbols == selected_symbols
        else
          mana_symbols.intersect?(selected_symbols)
        end
      end
    end
  end
end
