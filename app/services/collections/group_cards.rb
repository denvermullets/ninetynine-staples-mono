module Collections
  class GroupCards < Service
    GROUPING_OPTIONS = %w[none rarity color].freeze
    RARITY_ORDER = %w[mythic rare uncommon common].freeze
    COLOR_ORDER = %w[White Blue Black Red Green Colorless Multicolor].freeze

    def initialize(cards:, grouping: 'none')
      @cards = cards
      @grouping = GROUPING_OPTIONS.include?(grouping) ? grouping : 'none'
    end

    def call
      return {} if @cards.empty?
      return { 'All Cards' => @cards.to_a } if @grouping == 'none'

      grouped = @cards.group_by { |card| group_key(card) }
      sort_groups(grouped)
    end

    private

    def group_key(card)
      send("group_by_#{@grouping}", card)
    end

    def group_by_none(_card)
      'All Cards'
    end

    def group_by_rarity(card)
      card.rarity&.capitalize || 'Unknown'
    end

    def group_by_color(card)
      colors = card.colors
      return 'Colorless' if colors.empty?
      return 'Multicolor' if colors.size > 1

      colors.first.name
    end

    def sort_groups(grouped)
      sorter = group_sorter
      grouped.sort_by { |k, _| sorter.call(k) }.to_h
    end

    def group_sorter
      case @grouping
      when 'rarity'
        ->(k) { [RARITY_ORDER.index(k.downcase) || 999, k] }
      when 'color'
        ->(k) { [COLOR_ORDER.index(k) || 999, k] }
      else
        lambda(&:to_s)
      end
    end
  end
end
