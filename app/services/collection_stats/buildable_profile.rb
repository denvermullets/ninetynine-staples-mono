module CollectionStats
  # The collection, bucketed by colour identity, so the brew page can ask "what could I build in
  # these colours" without measuring every commander against every card.
  #
  # `colors` has exactly 5 rows, so there are 32 possible identities. Profiling once per identity
  # turns commander scoring from 3,235 x 20k into 3,235 lookups against a 32-entry hash - see
  # Commanders::ColorMask for the bit layout and Commanders::Buildability for the submask sum.
  #
  # NOTHING HERE IS PERSISTED. STA-273 originally specced a collection_color_profiles table rebuilt
  # nightly; the whole aggregate measures 115ms warm against a collection covering 13.9k distinct
  # oracle ids, and 210ms against every printing in the database, so it runs per request instead.
  # That is one query per page load rather than per row, it needs no invalidation - production has
  # no cache store - and it cannot serve a stale answer to somebody who just added the card they
  # are looking for.
  #
  # Counts are DISTINCT ORACLE IDS, not copies. Commander is singleton, so four printings of Cultivate
  # is one ramp card you can put in the deck, and a second copy adds nothing to what is buildable.
  class BuildableProfile < Base
    include MaskedOracles

    EMPTY_MASK = { role_counts: {}, effect_counts: {}, distinct_cards: 0 }.freeze

    # Positions in the plucked tuple, for the reads that cannot destructure it in a block signature.
    COUNT = 3
    ROLE_GROUPED = 4

    # -> { mask => { role_counts:, effect_counts:, distinct_cards: } } for all 32 masks
    def call
      return blank_profile if no_collections?

      grouped = aggregate.group_by(&:first)
      Commanders::ColorMask::MASKS.index_with { |mask| build_mask(grouped[mask]) }
    end

    private

    # GROUPING SETS, so role counts, effect counts and the card total come out of one pass.
    #
    # The three groupings cannot be derived from each other. A card tagged both ramp/mana_rock and
    # ramp/mana_dork is ONE ramp card, so summing its effect counts would count it twice; and a card
    # tagged ramp and card_draw is one card in distinct_cards but appears under both roles. Only
    # COUNT(DISTINCT) at each level gets all three right.
    #
    # GROUPING() IS LOAD-BEARING, NOT DECORATION. All three grouping sets emit a row with role NULL
    # and effect NULL for the same mask - the finest set emits one for cards the LEFT JOIN missed
    # (no detected role at all), and the coarser sets emit one because they aggregated the column
    # away. They are indistinguishable by their NULLs, so telling them apart by NULL alone reads the
    # "cards with no role" count as the mask total, which comes out smaller than the role counts
    # sitting next to it.
    def aggregate
      roled_oracles
        .group(Arel.sql('GROUPING SETS ((mask, card_roles.role, card_roles.effect), ' \
                        '(mask, card_roles.role), (mask))'))
        .pluck(Arel.sql('masked.mask'), Arel.sql('card_roles.role'), Arel.sql('card_roles.effect'),
               Arel.sql('COUNT(DISTINCT masked.scryfall_oracle_id)'),
               Arel.sql('GROUPING(card_roles.role)'), Arel.sql('GROUPING(card_roles.effect)'))
    end

    # LEFT JOIN to card_roles: a card with no detected role still belongs in distinct_cards, which is
    # the "owned pool" figure the page reports. The cast stays on the magic_cards side for the reason
    # Base#owned_by_oracle_rows gives - card_roles.scryfall_oracle_id is a string, and casting it
    # would make its index unusable.
    def roled_oracles
      masked_oracles
        .joins('LEFT JOIN card_roles ON card_roles.scryfall_oracle_id = masked.scryfall_oracle_id ' \
               "AND card_roles.confidence >= #{CardRole::HIGH_CONFIDENCE}")
    end

    # Which grouping set a row came from is read off the GROUPING flags, never off the NULLs.
    def build_mask(rows)
      return EMPTY_MASK if rows.blank?

      { role_counts: role_counts(rows), effect_counts: effect_counts(rows),
        distinct_cards: total_for(rows) }
    end

    # grouped-away effect, present role
    def role_counts(rows)
      rows.each_with_object({}) do |(_mask, role, _effect, count, role_grouped, effect_grouped), totals|
        totals[role] = count.to_i if role_grouped.zero? && effect_grouped == 1 && role
      end
    end

    # nothing grouped away, both present
    def effect_counts(rows)
      rows.each_with_object({}) do |(_mask, role, effect, count, role_grouped, effect_grouped), totals|
        totals[[role, effect]] = count.to_i if role_grouped.zero? && effect_grouped.zero? && role && effect
      end
    end

    # role grouped away entirely - the one row per mask that counts every owned card in it
    def total_for(rows)
      rows.find { |row| row[ROLE_GROUPED] == 1 }&.fetch(COUNT).to_i
    end

    def blank_profile
      Commanders::ColorMask::MASKS.index_with { EMPTY_MASK }
    end
  end
end
