# Rarity breakdown - copies and value per rarity.
#
# Ordering happens in Ruby against Collections::GroupCards::RARITY_ORDER rather than in SQL, so
# the analytics page and the collection page's rarity grouping always agree on what comes first.
# Rarities the app does not have an opinion about (special, bonus, nil) sort to the end rather
# than being dropped - they are real cards and their value has to land somewhere.
module CollectionStats
  class Rarity < Base
    ORDER = Collections::GroupCards::RARITY_ORDER
    BAR_CLASSES = {
      'mythic' => 'bg-accent-200',
      'rare' => 'bg-accent-300',
      'uncommon' => 'bg-grey-text',
      'common' => 'bg-highlight'
    }.freeze

    def call
      return [] if no_collections?

      rows = fetch
      total_value = rows.sum { |row| row[:value] }

      rows.sort_by { |row| sort_key(row) }
          .map { |row| row.merge(share: share(row[:value], total_value)) }
    end

    private

    def fetch
      owned_cards
        .group('magic_cards.rarity')
        .pluck(Arel.sql('magic_cards.rarity'), Arel.sql("SUM(#{TOTAL_QTY})"),
               Arel.sql("SUM(#{TOTAL_VALUE})"), Arel.sql('COUNT(*)'))
        .map { |rarity, copies, value, printings| build_row(rarity, copies, value, printings) }
    end

    def build_row(rarity, copies, value, printings)
      {
        rarity: rarity,
        label: rarity&.capitalize || 'Unknown',
        copies: copies.to_i,
        value: to_money(value || 0),
        printings: printings.to_i,
        bar_class: BAR_CLASSES.fetch(rarity, 'bg-highlight')
      }
    end

    def sort_key(row)
      [ORDER.index(row[:rarity].to_s.downcase) || ORDER.size, row[:label]]
    end
  end
end
