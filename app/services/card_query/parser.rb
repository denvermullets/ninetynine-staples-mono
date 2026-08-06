#
# splits a search box string into structured terms plus leftover free text
#
# Detection is automatic: a query is "advanced" only once it contains at least one token
# whose key is in FieldRegistry. Anything else - bare words, or a key the registry doesn't
# know - falls through to free text, so a card name that happens to contain a colon still
# searches by name instead of blowing up. When nothing parses, the caller keeps using the
# original string and the name search behaves exactly as it did before this existed.
#
# A known key with an unusable value (`mv>=banana`) is dropped and reported in `ignored`
# rather than folded into the name search, which would silently return nothing.
#
# This never raises. A malformed query degrades to a name search rather than 500ing.
#
module CardQuery
  class Parser < Service
    Result = Struct.new(:terms, :free_text, :ignored, keyword_init: true) do
      def advanced? = terms.any?
    end

    # a token is an optional `-`, an optional `key<op>`, then either a quoted phrase or a
    # run of non-space characters
    TOKEN = /
      (-)?
      (?:([A-Za-z]+)\s*(!=|>=|<=|:|=|>|<))?
      ("(?:[^"\\]|\\.)*"|\S+)
    /x

    NUMERIC = /\A-?\d+(\.\d+)?\z/

    ORDERED_OPS = %w[> >= < <=].freeze

    BOOLEANS = %w[true false yes no].freeze

    def initialize(query:)
      @query = query.to_s
    end

    def call
      @terms = []
      @free_text = []
      @ignored = []

      each_token { |match| consume(match) }

      Result.new(terms: @terms, free_text: @free_text.join(' ').strip, ignored: @ignored)
    end

    private

    # scan gives us the captures but not the raw matched text, and we need the raw text to
    # put unrecognized tokens back into the free-text search verbatim
    def each_token(&)
      @query.to_enum(:scan, TOKEN).map { Regexp.last_match }.each(&)
    end

    def consume(match)
      field = match[2] && FieldRegistry[match[2]]
      return @free_text << match[0] if field.nil?

      op = normalize_op(match[3], field)
      value = unquote(match[4])

      return @ignored << match[0] unless valid_value?(field, op, value)

      @terms << Term.new(key: match[2].downcase, op: op, value: value, negated: match[1] == '-')
    end

    def unquote(raw)
      return '' if raw.nil?
      return raw unless raw.start_with?('"') && raw.end_with?('"') && raw.length > 1

      raw[1..-2].gsub(/\\(.)/, '\1')
    end

    # `:` means something different per field - "contains this color" but "equals this mana
    # value" - so the registry names the comparison each field wants and handlers only ever
    # see a real operator
    def normalize_op(raw_op, field)
      return field[:default_op] || ':' if raw_op == ':'

      raw_op
    end

    def valid_value?(field, operator, value)
      return false if value.blank?

      case field[:handler]
      when :numeric, :numeric_cast, :price, :price_change, :owned_qty then value.match?(NUMERIC)
      when :color_set then valid_colors?(value)
      when :rarity then valid_rarity?(operator, value)
      when :flag then field[:values].include?(value.downcase)
      when :owned_flag, :owned_needed then BOOLEANS.include?(value.downcase)
      else true
      end
    end

    # colors are given as letters - "wu", "w/u" and "b" are all fine, anything else is a typo
    def valid_colors?(value)
      letters = ColorPredicate.letters(value)

      letters.present? && letters.all? { |letter| ColorPredicate::VALID.include?(letter) }
    end

    # `r:special` is a fine equality match even though it has no place in the ordering, but
    # `r>=special` has no meaning - only the four ordered rarities can be compared
    def valid_rarity?(operator, value)
      return true unless ORDERED_OPS.include?(operator)

      FieldRegistry::RARITY_ORDER.include?(value.downcase)
    end
  end
end
