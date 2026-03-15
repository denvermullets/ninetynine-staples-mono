module DeckRules
  class DetectBracket < Service
    def initialize(deck:)
      @deck = deck
    end

    def call
      brackets = Bracket.enabled.ordered.includes(:deck_rules)
      return { detected_bracket: nil, details: [] } if brackets.empty?

      game_changer_count = count_game_changers
      details = []

      detected = brackets.detect do |bracket|
        rules = bracket.deck_rules.select(&:enabled)
        next true if rules.empty?

        rules.all? do |rule|
          result = evaluate_rule(rule, game_changer_count)
          details << { bracket_level: bracket.level, rule: rule.name, passed: result[:passed],
                       actual: result[:actual], limit: rule.value }
          result[:passed]
        end
      end

      {
        detected_bracket: detected,
        game_changer_count: game_changer_count,
        details: details
      }
    end

    BASIC_LAND_NAMES = %w[Plains Island Swamp Mountain Forest Wastes].freeze

    private

    def evaluate_rule(rule, game_changer_count)
      case rule.rule_type
      when 'max_game_changers'
        { passed: game_changer_count <= rule.value, actual: game_changer_count }
      when 'max_deck_size'
        total = deck_card_count
        { passed: total <= rule.value, actual: total }
      when 'max_copies_per_card'
        max_copies = max_non_basic_copies
        { passed: max_copies <= rule.value, actual: max_copies }
      else
        { passed: true, actual: 0 }
      end
    end

    def count_game_changers
      gc_oracle_ids = GameChanger.pluck(:oracle_id)
      return 0 if gc_oracle_ids.empty?

      deck_oracle_ids = @deck.collection_magic_cards
                             .joins(:magic_card)
                             .where.not(board_type: 'commander')
                             .pluck('magic_cards.scryfall_oracle_id')

      (deck_oracle_ids & gc_oracle_ids).size
    end

    def deck_card_count
      @deck.collection_magic_cards.sum(:quantity) +
        @deck.collection_magic_cards.sum(:foil_quantity) +
        @deck.collection_magic_cards.sum(:proxy_quantity) +
        @deck.collection_magic_cards.sum(:proxy_foil_quantity)
    end

    def max_non_basic_copies
      @deck.collection_magic_cards
           .joins(:magic_card)
           .where.not(board_type: 'commander')
           .where.not(magic_cards: { name: BASIC_LAND_NAMES })
           .group('magic_cards.scryfall_oracle_id')
           .sum('collection_magic_cards.quantity + collection_magic_cards.foil_quantity + ' \
                'collection_magic_cards.proxy_quantity + collection_magic_cards.proxy_foil_quantity')
           .values
           .max || 0
    end
  end
end
