# What the cards actually do, read straight off card_roles.
#
# CardAnalysis::BatchProfiler already fills card_roles for every card the app has ingested, so
# nothing here analyses anything - it only joins. Two things about that table shape the panel:
#
# 1. Roles are per oracle id, not per printing, so everything goes through Base#owned_oracles.
#    Four printings of Swords to Plowshares is one removal card, not four.
# 2. A card can carry several effects inside the same role (a land tagged both shock_land and
#    dual_land, a spell tagged both draw and cantrip). Joining card_roles directly would then sum
#    that card's copies once per effect, so both queries join a DISTINCT subquery that has already
#    collapsed the effects down to the thing being counted.
#
# Coverage is partial and reported rather than hidden. Not every card has a detected role, so the
# panel says "roles detected for N% of your cards" instead of implying the rest do nothing.
module CollectionStats
  class Roles < Base
    # Curated, unlike the role panel: these are the questions people actually ask of a collection
    # ("how many board wipes do I own"), and there is no meaningful ranking between them, which is
    # why they render as chips rather than as bars.
    NOTABLE_EFFECTS = [
      { label: 'Counterspells', role: 'protection', effects: %w[counterspell] },
      { label: 'Board Wipes', role: 'removal', effects: %w[board_wipe] },
      { label: 'Spot Removal', role: 'removal', effects: %w[targeted_removal] },
      { label: 'Exile Removal', role: 'removal', effects: %w[exile_removal] },
      { label: 'Free / Cost-Reduced', role: 'ramp', effects: %w[cost_reduction] },
      { label: 'Rituals', role: 'ramp', effects: %w[ritual] },
      { label: 'Mana Rocks / Dorks', role: 'ramp', effects: %w[mana_rock mana_dork] },
      { label: 'Tutors', role: 'tutor', effects: %w[tutor_to_hand] },
      { label: 'Card Draw', role: 'card_draw', effects: %w[draw] },
      { label: 'Extra Turns', role: 'finisher', effects: %w[extra_turns] },
      { label: 'Alt Win Conditions', role: 'finisher', effects: %w[alt_wincon] },
      { label: 'Reanimation', role: 'recursion', effects: %w[reanimate] },
      { label: 'Fetches / Shocks / Duals', role: 'manabase',
        effects: %w[fetch_land shock_land dual_land] }
    ].freeze

    HAS_ROLE = <<~SQL.squish.freeze
      EXISTS (SELECT 1 FROM card_roles
              WHERE card_roles.scryfall_oracle_id = owned_by_oracle.scryfall_oracle_id
                AND card_roles.confidence >= #{CardRole::HIGH_CONFIDENCE})
    SQL

    EMPTY = { roles: [], effects: [], covered_printings: 0, total_printings: 0,
              coverage_share: 0.0 }.freeze

    def call
      return EMPTY if no_collections?

      { roles: role_rows, effects: effect_rows }.merge(coverage)
    end

    private

    # every role, including the ones nobody owns - a stable set of rows beats a panel that changes
    # shape as cards come and go, and an empty row is itself an answer
    def role_rows
      found = fetch_roles
      total = found.values.sum { |row| row[:copies] }

      CardRole::ROLES
        .map { |role| build_role(role, found[role], total) }
        .sort_by { |row| [-row[:copies], row[:label]] }
    end

    def build_role(role, found, total)
      copies = found ? found[:copies] : 0

      {
        role: role,
        label: role.titleize,
        copies: copies,
        cards: found ? found[:cards] : 0,
        value: to_money(found ? found[:value] : 0),
        share: share(copies, total),
        bar_class: 'bg-accent-50'
      }
    end

    def fetch_roles
      aggregate(distinct_roles, 'roles', 'role')
        .to_h { |role, copies, value, cards| [role, totals(copies, value, cards)] }
    end

    def effect_rows
      found = aggregate(distinct_chips, 'chips', 'chip_id')
              .to_h { |chip_id, copies, value, cards| [chip_id.to_i, totals(copies, value, cards)] }

      NOTABLE_EFFECTS.each_with_index.map { |chip, index| build_chip(chip, found[index]) }
    end

    def build_chip(chip, found)
      {
        label: chip[:label],
        copies: found ? found[:copies] : 0,
        cards: found ? found[:cards] : 0,
        value: to_money(found ? found[:value] : 0)
      }
    end

    # one row per oracle id per bucket, so SUM cannot double count a card that matched twice
    def distinct_roles
      CardRole.high_confidence
              .select('DISTINCT card_roles.scryfall_oracle_id, card_roles.role')
    end

    def distinct_chips
      notable
        .high_confidence
        .select("DISTINCT card_roles.scryfall_oracle_id, #{chip_case} AS chip_id")
    end

    # COUNT(*) is a count of oracle ids, not of printings - owned_by_oracle has already collapsed
    # those, which is the whole point of the CTE
    def aggregate(subquery, table, column)
      owned_oracles
        .joins("JOIN (#{subquery.to_sql}) #{table} " \
               "ON #{table}.scryfall_oracle_id = owned_by_oracle.scryfall_oracle_id")
        .group("#{table}.#{column}")
        .pluck(Arel.sql("#{table}.#{column}"), Arel.sql('SUM(owned_by_oracle.copies)'),
               Arel.sql('SUM(owned_by_oracle.value)'), Arel.sql('COUNT(*)'))
    end

    def totals(copies, value, cards)
      { copies: copies.to_i, value: value || 0, cards: cards.to_i }
    end

    def notable
      NOTABLE_EFFECTS
        .map { |chip| CardRole.where(role: chip[:role], effect: chip[:effects]) }
        .reduce(:or)
    end

    # the chip index doubles as its id: it survives the round trip through SQL without any quoting
    # of labels, and it hands back the curated order for free
    def chip_case
      whens = NOTABLE_EFFECTS.each_with_index.map do |chip, index|
        "WHEN card_roles.role = #{quote(chip[:role])} " \
          "AND card_roles.effect IN (#{chip[:effects].map { |effect| quote(effect) }.join(', ')}) " \
          "THEN #{index}"
      end

      "CASE #{whens.join(' ')} END"
    end

    def quote(value)
      CardRole.connection.quote(value)
    end

    # printings, not cards: "roles detected for N% of your cards" is a claim about what is on the
    # shelf, and the denominator has to include the printings that matched nothing
    def coverage
      total, covered = owned_oracles.pick(
        Arel.sql('COALESCE(SUM(owned_by_oracle.printings), 0)'),
        Arel.sql("COALESCE(SUM(owned_by_oracle.printings) FILTER (WHERE #{HAS_ROLE}), 0)")
      )

      { covered_printings: covered.to_i, total_printings: total.to_i,
        coverage_share: share(covered.to_i, total.to_i) }
    end
  end
end
