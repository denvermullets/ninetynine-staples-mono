# Card type breakdown, plus the count of cards that could lead a deck.
#
# Ordering and labelling come from DeckBuilder::GroupCards::TYPE_ORDER so the dashboard agrees
# with the deck builder's type grouping. Anything outside that list folds into "Other" - the
# card_types table carries a long tail of un-set oddities (Eaturecray, Phenome-nom, Scheme) that
# would otherwise crowd out the types anyone cares about.
#
# A card typed "Artifact Creature" has two card_types rows and counts in both buckets. That is
# the right answer for "what is in here", and the panel subtext says so rather than leaving the
# reader to wonder why the copies exceed their card count. Shares are deliberately a share of
# type slots rather than of cards, so the bars fill the panel instead of overflowing it.
#
# can_be_commander is a boolean on magic_cards, not a card type, so it is reported separately
# instead of being wedged in as a type row.
module CollectionStats
  class CardTypes < Base
    ORDER = DeckBuilder::GroupCards::TYPE_ORDER
    OTHER = 'Other'.freeze

    def call
      return { types: [], possible_commanders: 0 } if no_collections?

      { types: type_rows, possible_commanders: possible_commanders }
    end

    private

    def type_rows
      merged = fetch.each_with_object({}) { |row, acc| accumulate(acc, row) }
      total = merged.values.sum { |row| row[:copies] }

      merged.values
            .sort_by { |row| sort_key(row) }
            .map { |row| row.merge(value: to_money(row[:value]), share: share(row[:copies], total)) }
    end

    def fetch
      owned_cards
        .joins('JOIN magic_card_types ON magic_card_types.magic_card_id = magic_cards.id')
        .joins('JOIN card_types ON card_types.id = magic_card_types.card_type_id')
        .group('card_types.name')
        .pluck(Arel.sql('card_types.name'), Arel.sql("SUM(#{TOTAL_QTY})"), Arel.sql("SUM(#{REAL_VALUE})"))
    end

    def accumulate(acc, row)
      name, copies, value = row
      label = ORDER.include?(name) ? name : OTHER
      bucket = acc[label] ||= { label: label, copies: 0, value: 0, bar_class: 'bg-accent-50' }

      bucket[:copies] += copies.to_i
      bucket[:value] += value || 0
    end

    def possible_commanders
      owned_cards.where(magic_cards: { can_be_commander: true }).count
    end

    def sort_key(row)
      [ORDER.index(row[:label]) || ORDER.size, row[:label]]
    end
  end
end
