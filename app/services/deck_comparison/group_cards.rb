# Groups comparison rows into the sections the page draws, by handing them to the precon deck grouping
# service - a DeckComparison::Row answers everything that service asks of a row.
#
# What is decided here is only which groupings a comparison offers. `zone` is left out because it
# depends on MTGJSON's camelCase board names, and the builder's `real_vs_proxy` because a pasted card
# has no finish; asking for either falls back to `type`.
#
# This wraps rather than subclasses: PreconDecks::GroupCards#initialize reads GROUPING_OPTIONS
# lexically, so a subclass's constant would be ignored and `zone` would get through.
module DeckComparison
  class GroupCards < Service
    GROUPING_OPTIONS = %w[type mana_value color color_identity rarity set none].freeze
    SORT_OPTIONS = PreconDecks::GroupCards::SORT_OPTIONS

    def initialize(cards:, grouping: 'type', sort_by: 'mana_value')
      @cards = cards
      @grouping = GROUPING_OPTIONS.include?(grouping) ? grouping : 'type'
      @sort_by = sort_by
    end

    def call
      PreconDecks::GroupCards.call(cards: @cards, grouping: @grouping, sort_by: @sort_by)
    end
  end
end
