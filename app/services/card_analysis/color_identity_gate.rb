module CardAnalysis
  # Commander color identity is a hard filter, not a score: a card outside the commander's identity is
  # not a worse suggestion, it is an illegal one. Shared by ReplacementFinder (card -> similar cards) and
  # CommanderSynergy (commander -> pool) so the two cannot drift apart on what "legal in this deck" means.
  #
  # Identity comes from MagicCardColorIdent directly rather than magic_card.colors: MagicCard declares
  # has_many :colors twice and the color-identity version silently shadows the mana-cost one, so the
  # association reads correctly today only by accident.
  class ColorIdentityGate < Service
    def self.color_ids_for(magic_card_ids:)
      MagicCardColorIdent.where(magic_card_id: magic_card_ids).pluck(:color_id).to_set
    end

    def initialize(oracle_ids:, allowed_color_ids:)
      @oracle_ids = oracle_ids
      @allowed_color_ids = allowed_color_ids
    end

    # Returns the subset of oracle_ids whose color identity fits inside allowed_color_ids, preserving the
    # input order. Colorless cards have no MagicCardColorIdent rows at all, so they fall through to an
    # empty set - a subset of everything - and always pass.
    def call
      color_map = candidate_color_map

      @oracle_ids.select do |oid|
        (color_map[oid] || Set.new).subset?(@allowed_color_ids)
      end
    end

    private

    def candidate_color_map
      MagicCardColorIdent
        .where(magic_card_id: representative_card_ids)
        .joins(:magic_card)
        .pluck('magic_cards.scryfall_oracle_id', :color_id)
        .group_by(&:first)
        .transform_values { |pairs| pairs.to_set(&:last) }
    end

    # One printing per oracle id is enough - identity is a property of the card, not the printing - and
    # checking every printing would multiply the join by the reprint count.
    def representative_card_ids
      MagicCard.where(scryfall_oracle_id: @oracle_ids, card_side: [nil, 'a'])
               .group(:scryfall_oracle_id)
               .pluck(Arel.sql('MAX(id)'))
    end
  end
end
