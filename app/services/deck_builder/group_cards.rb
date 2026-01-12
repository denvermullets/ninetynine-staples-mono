module DeckBuilder
  class GroupCards < Service
    GROUPING_OPTIONS = %w[type mana_value color color_identity rarity set none].freeze
    SORT_OPTIONS = %w[name mana_value price rarity edhrec salt].freeze

    TYPE_ORDER = %w[
      Creature Planeswalker Instant Sorcery Artifact Enchantment Land Battle Other
    ].freeze

    RARITY_ORDER = %w[mythic rare uncommon common].freeze

    def initialize(cards:, grouping: 'type', sort_by: 'mana_value')
      @cards = cards
      @grouping = GROUPING_OPTIONS.include?(grouping) ? grouping : 'type'
      @sort_by = SORT_OPTIONS.include?(sort_by) ? sort_by : 'mana_value'
    end

    def call
      return {} if @cards.empty?

      # Extract commanders first - they always get their own section
      commanders, other_cards = @cards.partition { |c| c.board_type == 'commander' }

      result = {}
      result['Commander'] = sort_cards(commanders) if commanders.any?

      # Group remaining cards
      grouped = other_cards.group_by { |card| group_key(card) }
      sorted_groups = sort_groups(grouped)

      # Sort cards within each group and merge
      sorted_groups.each { |group_name, cards| result[group_name] = sort_cards(cards) }

      result
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

    def sort_cards(cards)
      cards.sort_by { |c| card_sort_key(c) }
    end

    def card_sort_key(card)
      magic_card = card.magic_card
      name = magic_card.name.downcase

      sort_key_for(magic_card, name)
    end

    def sort_key_for(magic_card, name)
      case @sort_by
      when 'mana_value' then [magic_card.mana_value || 99, name]
      when 'price' then [(magic_card.normal_price || 0).to_f, name]
      when 'rarity' then [RARITY_ORDER.index(magic_card.rarity) || 99, name]
      when 'edhrec' then [magic_card.edhrec_rank || 999_999, name]
      when 'salt' then [-(magic_card.edhrec_saltiness || 0).to_f, name]
      else name
      end
    end
  end
end
