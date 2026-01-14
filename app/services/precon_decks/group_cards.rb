module PreconDecks
  class GroupCards < Service
    GROUPING_OPTIONS = %w[type mana_value color color_identity rarity set zone none].freeze
    SORT_OPTIONS = %w[name mana_value price rarity edhrec salt].freeze
    TYPE_ORDER = %w[Creature Planeswalker Instant Sorcery Artifact Enchantment Land Battle Other].freeze
    RARITY_ORDER = %w[mythic rare uncommon common].freeze
    ZONE_MAPPING = { 'commander' => 'Commander', 'mainBoard' => 'Main Board',
                     'sideBoard' => 'Sideboard', 'tokens' => 'Tokens' }.freeze
    GROUP_SORTERS = {
      'type' => ->(key) { [TYPE_ORDER.index(key) || 999, key] },
      'mana_value' => ->(key) { key == 'X' ? 999 : key.to_i },
      'rarity' => ->(key) { [RARITY_ORDER.index(key&.downcase) || 999, key] }
    }.freeze

    def initialize(cards:, grouping: 'type', sort_by: 'mana_value')
      @cards = cards
      @grouping = GROUPING_OPTIONS.include?(grouping) ? grouping : 'type'
      @sort_by = SORT_OPTIONS.include?(sort_by) ? sort_by : 'mana_value'
    end

    def call
      return {} if @cards.empty?

      @grouping == 'zone' ? group_by_zone : group_by_attribute
    end

    private

    def group_by_zone
      @cards.group_by(&:board_type)
            .transform_keys { |k| ZONE_MAPPING[k] || k }
            .transform_values { |cards| sort_cards(cards) }
            .sort_by { |k, _| ZONE_MAPPING.values.index(k) || 999 }.to_h
    end

    def group_by_attribute
      result = build_commander_section
      result.merge!(build_main_sections)
      result.merge!(build_tokens_section)
    end

    def build_commander_section
      commanders = @cards.select { |c| c.board_type == 'commander' }
      commanders.any? ? { 'Commander' => sort_cards(commanders) } : {}
    end

    def build_main_sections
      main_cards = @cards.reject { |c| %w[commander tokens].include?(c.board_type) }
      grouped = main_cards.group_by { |card| group_key(card) }
      sort_groups(grouped).transform_values { |cards| sort_cards(cards) }
    end

    def build_tokens_section
      tokens = @cards.select { |c| c.board_type == 'tokens' }
      tokens.any? ? { 'Tokens' => sort_cards(tokens) } : {}
    end

    def group_key(card)
      send("group_by_#{@grouping}", card)
    end

    def group_by_type(card) = card.magic_card.primary_type || 'Other'
    def group_by_mana_value(card) = (mv = card.magic_card.mana_value&.to_i) ? mv.to_s : 'X'

    def group_by_color(card)
      colors = card.magic_card.colors
      colors.empty? ? 'Colorless' : colors.map(&:name).sort.join('/')
    end

    def group_by_color_identity(card) = card.magic_card.color_identity_string.presence || 'Colorless'
    def group_by_rarity(card) = card.magic_card.rarity&.capitalize || 'Unknown'
    def group_by_set(card) = card.magic_card.boxset&.name || 'Unknown'
    def group_by_none(_card) = 'All Cards'

    def sort_groups(grouped)
      grouped.sort_by { |k, _| group_sort_value(k) }.to_h
    end

    def group_sort_value(key)
      (GROUP_SORTERS[@grouping] || lambda(&:to_s)).call(key)
    end

    def sort_cards(cards) = cards.sort_by { |c| [sort_value_for(c.magic_card), c.magic_card.name.downcase] }

    def sort_value_for(card) = send("sort_by_#{@sort_by}", card)
    def sort_by_name(card) = card.name.downcase
    def sort_by_mana_value(card) = card.mana_value || 99
    def sort_by_price(card) = (card.normal_price || 0).to_f
    def sort_by_rarity(card) = RARITY_ORDER.index(card.rarity) || 99
    def sort_by_edhrec(card) = card.edhrec_rank || 999_999
    def sort_by_salt(card) = -(card.edhrec_saltiness || 0).to_f
  end
end
