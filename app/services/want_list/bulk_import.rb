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
# The printing a new row points at is only an anchor, since any printing satisfies it. The cheapest
# priced front face from an ordinary paper set is used, so the list's price column reads as what filling
# the want would cost - and not what a gold-bordered World Championship copy or an Arena-only card costs.
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
      MagicCard.where(is_token: false).where.not(scryfall_oracle_id: nil)
    end

    def import(entries)
      resolved, unresolved = entries.values.partition { |entry| entry[:oracle_ids]&.one? }
      wanted = wanted_oracle_ids(resolved)
      new_entries, already = resolved.partition { |entry| wanted.exclude?(entry[:oracle_ids].first) }
      ambiguous, unknown = unresolved.partition { |entry| entry[:oracle_ids] }

      { added: create_items(new_entries), already_wanted: report(already), ambiguous: report(ambiguous),
        unresolved: report(unknown) }
    end

    # any row counts, specific printing included
    def wanted_oracle_ids(entries)
      @user.want_list_items.where(scryfall_oracle_id: entries.map { |entry| entry[:oracle_ids].first })
           .distinct.pluck(:scryfall_oracle_id).to_set
    end

    # lines as the user typed them, less the export noise, so they can be fixed and pasted back
    def report(entries)
      entries.map { |entry| entry.slice(:name, :quantity) }
    end

    def create_items(entries)
      printings = anchor_printings(entries.map { |e| e[:oracle_ids].first })

      entries.filter_map do |entry|
        card = printings[entry[:oracle_ids].first]
        next unless card

        item = @user.want_list_items.new(magic_card: card, quantity: entry[:quantity], any_printing: true)
        item if item.save
      end
    end

    # one printing per oracle id, skipping any the user already has a row on
    def anchor_printings(oracle_ids)
      return {} if oracle_ids.empty?

      candidates.left_joins(:boxset)
                .where(scryfall_oracle_id: oracle_ids)
                .where.not(id: @user.want_list_items.select(:magic_card_id))
                .select('DISTINCT ON (magic_cards.scryfall_oracle_id) magic_cards.*')
                .order(Arel.sql(CHOOSE_PRINTING_SQL))
                .index_by(&:scryfall_oracle_id)
    end
  end
end
