# Turns a pasted decklist into any-printing wants, one per card, and says which lines it could not use.
#
# Reading the paste is Decklist::Parse and pinning each typed name to a card is Decklist::Resolve, both
# shared with deck comparison. Which board a line sat under is ignored: a card under "Maybeboard" is
# still a card the user asked for.
#
# A name that lands on more than one card is reported as ambiguous rather than guessed. A card the user
# already wants in any form is left alone: re-pasting a list should not bump quantities or stack a
# second row on a specific-printing want.
#
# Adding the rows, and choosing the printing each one is anchored to, is WantList::AddByOracle.
module WantList
  class BulkImport < Service
    MAX_CARDS = Decklist::Parse::MAX_CARDS

    def initialize(user:, text:)
      @user = user
      @text = text.to_s
    end

    def call
      entries = Decklist::Parse.call(text: @text)
      return { success: false, error: "Paste at most #{MAX_CARDS} cards at a time." } if entries.size > MAX_CARDS

      { success: true, **import(Decklist::Resolve.call(entries: entries)) }
    end

    private

    def import(names)
      resolved = names[:resolved]
      result = AddByOracle.call(user: @user, quantities: quantities(resolved))
      already = resolved.select { |entry| result[:already_wanted].include?(entry[:oracle_id]) }

      { added: result[:added], already_wanted: report(already), ambiguous: report(names[:ambiguous]),
        unresolved: report(names[:unresolved]) }
    end

    # two names can land on one card ("Fire // Ice" and a lone "Ice"), so quantities are summed
    def quantities(entries)
      entries.each_with_object(Hash.new(0)) { |entry, totals| totals[entry[:oracle_id]] += entry[:quantity] }
    end

    # lines as the user typed them, less the export noise, so they can be fixed and pasted back
    def report(entries)
      entries.map { |entry| entry.slice(:name, :quantity) }
    end
  end
end
