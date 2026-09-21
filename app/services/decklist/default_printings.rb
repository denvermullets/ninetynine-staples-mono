# Picks the one printing that stands in for a card known only by oracle id - a pasted "1 Sol Ring" names
# no printing, and a want for any printing still has to point at one.
# -> { scryfall_oracle_id => MagicCard }, with no entry for an oracle id that has no usable printing.
#
# The cheapest priced front face from an ordinary paper set is used, newest first when nothing is
# priced. That is the copy quickest to grab, so a price shown beside it reads as what the card costs -
# and not what a gold-bordered World Championship copy or an Arena-only card costs.
#
# `except_card_ids` (a relation or an array) rules printings out, for a caller that cannot point at the
# same printing twice. `preload` is handed to `.preload` and never `.includes`: next to the custom
# DISTINCT ON select, `includes` can flip Rails into `eager_load` and mangle the select.
module Decklist
  class DefaultPrintings < Service
    # sets whose copies are a poor stand-in for "the card": digital, gold-bordered, silver-bordered, oddball
    UNUSUAL_SET_TYPES = %w[alchemy funny memorabilia minigame token treasure_chest vanguard].freeze

    CHOOSE_PRINTING_SQL = <<~SQL.squish.freeze
      magic_cards.scryfall_oracle_id,
      magic_cards.card_side = 'b' ASC NULLS FIRST,
      COALESCE(boxsets.set_type IN (#{UNUSUAL_SET_TYPES.map { |type| "'#{type}'" }.join(', ')}), FALSE) ASC,
      magic_cards.normal_price > 0 DESC NULLS LAST,
      magic_cards.normal_price ASC NULLS LAST,
      boxsets.release_date DESC NULLS LAST,
      magic_cards.id ASC
    SQL

    def initialize(oracle_ids:, except_card_ids: nil, preload: [])
      @oracle_ids = oracle_ids
      @except_card_ids = except_card_ids
      @preload = preload
    end

    def call
      return {} if @oracle_ids.empty?

      printings.select('DISTINCT ON (magic_cards.scryfall_oracle_id) magic_cards.*')
               .order(Arel.sql(CHOOSE_PRINTING_SQL))
               .preload(@preload)
               .index_by(&:scryfall_oracle_id)
    end

    private

    # the same printings a typed name can resolve to
    def printings
      scope = Resolve.candidates.left_joins(:boxset).where(scryfall_oracle_id: @oracle_ids)

      @except_card_ids.nil? ? scope : scope.where.not(id: @except_card_ids)
    end
  end
end
