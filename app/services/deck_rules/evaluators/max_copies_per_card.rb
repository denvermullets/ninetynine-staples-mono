module DeckRules
  module Evaluators
    class MaxCopiesPerCard < Base
      def evaluate
        copies_by_card = card_copy_counts
        max_copies = copies_by_card.values.max || 0
        offending = copies_by_card.select { |_, count| count > @rule.value }.map { |name, count| "#{name} (#{count})" }

        {
          passed: max_copies <= @rule.value,
          actual: max_copies,
          limit: @rule.value,
          rule_name: @rule.name,
          rule_type: @rule.rule_type,
          offending_cards: offending
        }
      end

      def violation_message
        copies_by_card = card_copy_counts
        offenders = copies_by_card.select { |_, count| count > @rule.value }
        offenders.map { |name, count| "#{name} has #{count} copies (limit: #{@rule.value})" }.join(', ')
      end

      private

      def card_copy_counts
        @context[:card_copy_counts] ||= begin
          counts_by_oracle = deck_cards
                             .where.not(collection_magic_cards: { board_type: 'commander' })
                             .where.not(magic_cards: { name: BASIC_LAND_NAMES })
                             .group('magic_cards.scryfall_oracle_id')
                             .sum('collection_magic_cards.quantity + collection_magic_cards.foil_quantity + ' \
                                  'collection_magic_cards.proxy_quantity + collection_magic_cards.proxy_foil_quantity')

          # Map oracle_ids to card names for offending_cards output
          oracle_ids = counts_by_oracle.keys
          names_map = MagicCard.where(scryfall_oracle_id: oracle_ids, card_side: [nil, 'a'])
                               .pluck(:scryfall_oracle_id, :name)
                               .to_h

          counts_by_oracle.transform_keys { |oracle_id| names_map[oracle_id] || oracle_id }
        end
      end
    end
  end
end
