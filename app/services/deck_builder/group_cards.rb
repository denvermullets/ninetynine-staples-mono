module DeckBuilder
  class GroupCards < Service
    GROUPING_OPTIONS = %w[type mana_value color color_identity rarity set none].freeze

    TYPE_ORDER = %w[
      Creature Planeswalker Instant Sorcery Artifact Enchantment Land Battle Other
    ].freeze

    def initialize(cards:, grouping: 'type')
      @cards = cards
      @grouping = GROUPING_OPTIONS.include?(grouping) ? grouping : 'type'
    end

    def call
      return {} if @cards.empty?

      grouped = @cards.group_by { |card| group_key(card) }
      sort_groups(grouped)
    end

    private

    def group_key(card)
      send("group_by_#{@grouping}", card)
    end

    def group_by_type(card)
      card.magic_card.primary_type || 'Other'
    end

    def group_by_mana_value(card)
      mv = card.magic_card.mana_value&.to_i
      mv.nil? ? 'X' : mv.to_s
    end

    def group_by_color(card)
      colors = card.magic_card.colors
      return 'Colorless' if colors.empty?

      colors.map(&:name).sort.join('/')
    end

    def group_by_color_identity(card)
      card.magic_card.color_identity_string.presence || 'Colorless'
    end

    def group_by_rarity(card)
      card.magic_card.rarity&.capitalize || 'Unknown'
    end

    def group_by_set(card)
      card.magic_card.boxset&.name || 'Unknown'
    end

    def group_by_none(_card)
      'All Cards'
    end

    def sort_groups(grouped)
      sorter = group_sorter
      grouped.sort_by { |k, _| sorter.call(k) }.to_h
    end

    def group_sorter
      case @grouping
      when 'type'
        ->(k) { [TYPE_ORDER.index(k) || 999, k] }
      when 'mana_value'
        ->(k) { k == 'X' ? 999 : k.to_i }
      else
        lambda(&:to_s)
      end
    end
  end
end
