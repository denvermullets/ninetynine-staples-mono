# Groups the admin game changer list into color sections. Game changers are a Commander list, so the
# sections follow color identity rather than card color - a mono-red card with a {G} ability sits
# under Multicolor here.
module GameChangers
  class GroupByColor < Service
    ORDER = %w[White Blue Black Red Green Multicolor Colorless Land].freeze

    def initialize(game_changers:)
      @game_changers = game_changers
    end

    def call
      cards_by_oracle = load_cards
      grouped = @game_changers.group_by { |gc| group_for(cards_by_oracle[gc.oracle_id]) }
      grouped.sort_by { |group, _| ORDER.index(group) || ORDER.size }
    end

    private

    def load_cards
      MagicCard
        .where(scryfall_oracle_id: @game_changers.map(&:oracle_id), card_side: [nil, 'a'])
        .select('DISTINCT ON (scryfall_oracle_id) *')
        .order(:scryfall_oracle_id)
        .includes(:color_identities)
        .index_by(&:scryfall_oracle_id)
    end

    def group_for(magic_card)
      return 'Colorless' unless magic_card

      color_names = magic_card.color_identities.map(&:display_name)
      return 'Land' if color_names.empty? && magic_card.card_type.to_s.include?('Land')
      return 'Multicolor' if color_names.size > 1

      color_names.first || 'Colorless'
    end
  end
end
