# Turns a pasted decklist into any-printing wants, one per card, and says which lines it could not use.
#
# Nothing else in the app resolves a typed card name: precons arrive keyed by MTGJSON uuid, CSV imports
# by Scryfall id, and the deck builder's bulk import searches one line at a time for the user to pick.
# A want only needs the card, not a printing, so names are resolved here in two batched lookups -
# full names first ("Fire // Ice"), then single faces ("Fire") for whatever is left.
#
# A name that lands on more than one oracle id (the Unfinity attraction variants, "Fire" as a face of
# two split cards) is reported as ambiguous rather than guessed. A card the user already wants in any
# form is left alone: re-pasting a list should not bump quantities or stack a second row on a
# specific-printing want.
#
# Adding the rows, and choosing the printing each one is anchored to, is WantList::AddByOracle.
module WantList
  class BulkImport < Service
    MAX_CARDS = 500

    SECTION_HEADERS = /\A(commander|companions?|deck|main\s*board|side\s*board|maybe\s*board|considering|tokens?)\z/i

    # trailing export noise: Moxfield's "(C21) 263 *F*", Archidekt's "[Ramp]" and "^Have,#37d67a^"
    TRAILING_NOISE = [
      /\s+\^[^^]*\^\s*\z/,
      /\s+\[[^\]]*\]\s*\z/,
      /\s+\*[A-Z]+\*\s*\z/i,
      /\s+\(\s*[A-Za-z0-9]{2,6}\s*\)(\s+\S+)?\s*\z/
    ].freeze

    LINE = /\A(?:(\d{1,3})\s*x?\s+)?(.+)\z/i

    def initialize(user:, text:)
      @user = user
      @text = text.to_s
    end

    def call
      entries = parse
      return { success: false, error: "Paste at most #{MAX_CARDS} cards at a time." } if entries.size > MAX_CARDS

      resolve(entries)
      { success: true, **import(entries) }
    end

    private

    # one entry per distinct name, keyed by its normalized form, with repeated lines' quantities summed
    def parse
      @text.each_line.with_object({}) do |raw, entries|
        line = raw.strip
        next if skip_line?(line)

        quantity, name = parse_line(line)
        next if name.blank?

        entry = entries[normalize(name)] ||= { name: name, quantity: 0 }
        entry[:quantity] += quantity
      end
    end

    def skip_line?(line)
      line.empty? || line.start_with?('#', '//') || line.end_with?(':') || line.match?(SECTION_HEADERS)
    end

    def parse_line(line)
      quantity, name = LINE.match(line).captures
      name = TRAILING_NOISE.reduce(name) { |stripped, noise| stripped.sub(noise, '') }

      [[quantity.to_i, 1].max, name.strip]
    end

    # case, curly apostrophes and the spacing around a split card's slashes are all typed loosely
    def normalize(name)
      name.tr('’‘', "''").gsub(%r{\s*//?\s*}, ' // ').squish.downcase
    end

    # sets entries[key][:oracle_ids] to every card the name could mean
    def resolve(entries)
      assign_oracle_ids(entries, :name, entries.keys)
      unmatched = entries.select { |_key, entry| entry[:oracle_ids].blank? }.keys
      assign_oracle_ids(entries, :face_name, unmatched)
    end

    def assign_oracle_ids(entries, column, keys)
      return if keys.empty?

      lowered = MagicCard.arel_table[column].lower

      candidates.where(lowered.in(keys))
                .distinct
                .pluck(lowered, :scryfall_oracle_id)
                .group_by(&:first)
                .each { |key, rows| entries[key][:oracle_ids] = rows.map(&:last) }
    end

    def candidates
      AddByOracle.candidates
    end

    def import(entries)
      resolved, unresolved = entries.values.partition { |entry| entry[:oracle_ids]&.one? }
      result = AddByOracle.call(user: @user, quantities: quantities(resolved))
      already = resolved.select { |entry| result[:already_wanted].include?(entry[:oracle_ids].first) }
      ambiguous, unknown = unresolved.partition { |entry| entry[:oracle_ids] }

      { added: result[:added], already_wanted: report(already), ambiguous: report(ambiguous),
        unresolved: report(unknown) }
    end

    # two names can land on one card ("Fire // Ice" and a lone "Ice"), so quantities are summed
    def quantities(entries)
      entries.each_with_object(Hash.new(0)) { |entry, totals| totals[entry[:oracle_ids].first] += entry[:quantity] }
    end

    # lines as the user typed them, less the export noise, so they can be fixed and pasted back
    def report(entries)
      entries.map { |entry| entry.slice(:name, :quantity) }
    end
  end
end
