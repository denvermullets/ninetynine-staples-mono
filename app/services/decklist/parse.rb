# Reads a pasted decklist into one entry per distinct card name: how many copies, and which board the
# line sat under. It knows nothing about the cards table - pinning a typed name to a card is
# Decklist::Resolve - so the want importer and deck comparison can share one reading of a paste.
#
# Lists arrive from Moxfield, Archidekt and hand-typed notes, so a line is read loosely: an optional
# "4" or "4x", the name, and whatever the exporter hung off the end. Entries are keyed by the name's
# normalized form, which is also what Resolve looks up, and keep the name as typed so a line that
# could not be used can be shown back, fixed and pasted again.
#
# A section header ("Commander", "SIDEBOARD:") is not a card, but it says where the cards under it
# belong - without it a pasted list loses which card is the commander. A name repeated under two
# headers is one entry on the first board it was seen in. MAX_CARDS is only published here: callers
# check the size themselves, since each words its own error.
module Decklist
  class Parse < Service
    MAX_CARDS = 500

    SECTION_HEADERS = /\A(commander|companions?|deck|main\s*board|side\s*board|maybe\s*board|considering|tokens?)\z/i

    # first match wins; a companion is played from outside the deck but is still one of its cards
    BOARDS = {
      /\Acommander/i => 'commander',
      /\Aside/i => 'sideboard',
      /\A(maybe|considering)/i => 'maybeboard',
      /\Atoken/i => 'tokens'
    }.freeze

    DEFAULT_BOARD = 'mainboard'.freeze

    # trailing export noise: Moxfield's "(C21) 263 *F*", Archidekt's "[Ramp]" and "^Have,#37d67a^"
    TRAILING_NOISE = [
      /\s+\^[^^]*\^\s*\z/,
      /\s+\[[^\]]*\]\s*\z/,
      /\s+\*[A-Z]+\*\s*\z/i,
      /\s+\(\s*[A-Za-z0-9]{2,6}\s*\)(\s+\S+)?\s*\z/
    ].freeze

    LINE = /\A(?:(\d{1,3})\s*x?\s+)?(.+)\z/i

    # case, curly apostrophes and the spacing around a split card's slashes are all typed loosely
    def self.normalize(name)
      name.tr('’‘', "''").gsub(%r{\s*//?\s*}, ' // ').squish.downcase
    end

    def initialize(text:)
      @text = text.to_s
    end

    # { normalized_name => { name:, quantity:, board: } } in the order the names first appear
    def call
      board = DEFAULT_BOARD

      @text.each_line.with_object({}) do |raw, entries|
        line = raw.strip
        header = header_board(line)
        board = header if header
        next if header || skip_line?(line)

        add_entry(entries, line, board)
      end
    end

    private

    # the board a header line opens, or nil for any other line; exporters write both "Commander" and "COMMANDER:"
    def header_board(line)
      header = line.delete_suffix(':').strip
      return unless header.match?(SECTION_HEADERS)

      BOARDS.find { |pattern, _board| header.match?(pattern) }&.last || DEFAULT_BOARD
    end

    def skip_line?(line)
      line.empty? || line.start_with?('#', '//') || line.end_with?(':')
    end

    # repeated lines sum their quantities, and the first board seen for a name wins
    def add_entry(entries, line, board)
      quantity, name = parse_line(line)
      return if name.blank?

      entry = entries[self.class.normalize(name)] ||= { name: name, quantity: 0, board: board }
      entry[:quantity] += quantity
    end

    def parse_line(line)
      quantity, name = LINE.match(line).captures
      name = TRAILING_NOISE.reduce(name) { |stripped, noise| stripped.sub(noise, '') }

      [[quantity.to_i, 1].max, name.strip]
    end
  end
end
