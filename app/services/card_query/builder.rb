#
# folds parsed terms onto a card relation
#
# The relation this receives is already grouped by magic_cards.id with SUM(...) aggregates in
# its SELECT (see Search::Collection#sort_cards), so adding joins here would fan the rows out
# and inflate those sums - the table would show the wrong owned quantity. Every card-level
# predicate is therefore an IN / EXISTS subquery against magic_cards.id, which composes with
# the grouping without touching the row count. CollectionQuery::Filter#filter_by_exact_colors
# is the existing example of the same approach.
#
# Ownership terms are the exception: they're HAVING clauses over the aggregates that are
# already there, and they only apply when the relation is actually grouped - same guard
# CollectionQuery::Filter#exclude_proxy_only uses.
#
# Every handler returns [sql, *binds] ready to splat into `where` or `having`. Table and
# column names come from FieldRegistry; user values are always bound.
#
module CardQuery
  class Builder < Service
    # power/toughness are varchar and hold things like "*" and "1+*". Pull off a leading
    # integer and let everything else become NULL - REGEXP_REPLACE would happily produce
    # "--" and blow up the cast.
    #
    # The optional sign is written `-{0,1}` rather than `-?` on purpose: Rails scans the SQL
    # string for `?` placeholders and would count the quantifier as a missing bind.
    NUMERIC_CAST = "NULLIF(SUBSTRING(magic_cards.%<column>s FROM '^-{0,1}[0-9]+'), '')::numeric".freeze

    COMPARISONS = %w[= != > >= < <=].freeze

    # the is: values that are just a boolean column
    FLAG_COLUMNS = {
      'commander' => 'can_be_commander',
      'brawlcommander' => 'can_be_brawl_commander',
      'oathbreaker' => 'can_be_oathbreaker_commander',
      'token' => 'is_token',
      'reprint' => 'is_reprint',
      'reserved' => 'is_reserved'
    }.freeze

    def initialize(cards:, terms:)
      @cards = cards
      @terms = Array(terms)
    end

    def call
      @terms.reduce(@cards) { |cards, term| apply(cards, term) }
    end

    private

    def apply(cards, term)
      field = FieldRegistry[term.key]
      return cards if field.nil?

      predicate = predicate_for(field, term)
      return cards if predicate.nil?

      predicate = maybe_negate(predicate, term)

      field[:kind] == :owned ? apply_having(cards, predicate) : cards.where(*predicate)
    end

    # handler names come from the registry, never from params
    def predicate_for(field, term)
      send(:"predicate_for_#{field[:handler]}", field, term)
    end

    def apply_having(cards, predicate)
      return cards unless cards.respond_to?(:group_values) && cards.group_values.present?

      cards.having(*predicate)
    end

    # NULL columns should drop out of a positive match but survive a negated one, so a card
    # with no type line still counts as "not a creature"
    def maybe_negate(predicate, term)
      return predicate unless term.negated?

      ["NOT COALESCE((#{predicate.first}), FALSE)", *predicate.drop(1)]
    end

    # --- card attributes ------------------------------------------------------------------

    def predicate_for_color_set(field, term)
      ColorPredicate.call(operator: term.op, value: term.value, join_table: field[:join_table])
    end

    def predicate_for_type(_field, term)
      TypePredicate.call(operator: term.op, value: term.value)
    end

    # `:` is a substring match, `=` pins the whole value
    def predicate_for_ilike(field, term)
      column = "magic_cards.#{field[:column]}"

      case term.op
      when '=' then ["#{column} ILIKE ?", term.value]
      when '!=' then ["NOT COALESCE((#{column} ILIKE ?), FALSE)", term.value]
      else ["#{column} ILIKE ?", "%#{sanitize_like(term.value)}%"]
      end
    end

    # rarity is a varchar with no natural ordering, so `r>=rare` compares positions in the
    # allowlist instead. Anything outside it (special, bonus) sorts to NULL and drops out of
    # comparisons, but still works as a plain equality match.
    def predicate_for_rarity(_field, term)
      return rarity_equality(term) unless term.comparison?

      position = FieldRegistry::RARITY_ORDER.index(term.value.downcase) + 1

      ["array_position(ARRAY[?]::varchar[], magic_cards.rarity) #{term.op} ?",
       FieldRegistry::RARITY_ORDER, position]
    end

    def rarity_equality(term)
      sql = 'LOWER(magic_cards.rarity) = LOWER(?)'

      term.op == '!=' ? ["NOT COALESCE((#{sql}), FALSE)", term.value] : [sql, term.value]
    end

    def predicate_for_numeric(field, term)
      comparison("magic_cards.#{field[:column]}", term, default: '=')
    end

    def predicate_for_numeric_cast(field, term)
      comparison(format(NUMERIC_CAST, column: field[:column]), term, default: '=')
    end

    def predicate_for_set_code(_field, term)
      ['magic_cards.boxset_id IN (SELECT boxsets.id FROM boxsets WHERE UPPER(boxsets.code) = UPPER(?))',
       term.value]
    end

    def predicate_for_assoc(field, term)
      match, value = if field[:exact]
                       ["LOWER(#{field[:lookup_table]}.#{field[:lookup_column]}) = LOWER(?)", term.value]
                     else
                       ["#{field[:lookup_table]}.#{field[:lookup_column]} ILIKE ?",
                        "%#{sanitize_like(term.value)}%"]
                     end

      [subquery(field[:join_table], field[:lookup_table], field[:fk], match), value]
    end

    def predicate_for_card_role(field, term)
      CardRolePredicate.call(column: field[:column], value: term.value)
    end

    # commander:"Prossh, Skyraider of Kher" is the colour identity subset relation with the letters looked
    # up from a name. nil back from the resolver means the name matched nothing, and apply/1 reads that as
    # "skip this term".
    def predicate_for_commander_identity(_field, term)
      letters = CommanderIdentity.call(name: term.value)
      return nil if letters.nil?

      ColorPredicate.call(
        operator: '<=', value: letters.presence || ColorPredicate::COLORLESS,
        join_table: 'magic_card_color_idents'
      )
    end

    def predicate_for_legality(field, term)
      [
        "magic_cards.id IN (
           SELECT magic_card_legalities.magic_card_id FROM magic_card_legalities
           INNER JOIN legalities ON legalities.id = magic_card_legalities.legality_id
           WHERE LOWER(legalities.name) = LOWER(?) AND magic_card_legalities.status = ?
         )".squish,
        term.value,
        field[:status]
      ]
    end

    def predicate_for_flag(_field, term)
      value = term.value.downcase
      column = FLAG_COLUMNS[value]
      return ["magic_cards.#{column} = TRUE"] if column

      case value
      when 'dfc' then ['magic_cards.other_face_uuid IS NOT NULL']
      when 'colorless' then ColorPredicate.call(operator: ':', value: 'c', join_table: 'magic_card_colors')
      else finish_predicate(value)
      end
    end

    def finish_predicate(name)
      [subquery('magic_card_finishes', 'finishes', 'finish_id', 'LOWER(finishes.name) = LOWER(?)'), name]
    end

    # --- prices ------------------------------------------------------------------------------

    def predicate_for_price(field, term)
      comparison("magic_cards.#{field[:column]}", term, default: '>=')
    end

    # mirrors CollectionQuery::Filter#filter_by_price_change - either finish moving past the
    # threshold counts
    def predicate_for_price_change(_field, term)
      op = operator(term, default: '>=')

      ["(magic_cards.price_change_weekly_normal #{op} ? OR magic_cards.price_change_weekly_foil #{op} ?)",
       term.value.to_f, term.value.to_f]
    end

    # --- ownership ------------------------------------------------------------------------------
    # HAVING over aggregates rather than a subquery - see OwnedPredicate for why

    def predicate_for_owned_qty(_field, term) = owned(:owned_qty, term)
    def predicate_for_owned_flag(field, term) = owned(:owned_flag, term, columns: field[:columns])
    def predicate_for_owned_needed(_field, term) = owned(:owned_needed, term)

    def owned(handler, term, columns: nil)
      OwnedPredicate.call(handler: handler, operator: operator(term, default: '>='),
                          value: term.value, columns: columns)
    end

    # --- shared helpers ----------------------------------------------------------------------------

    def comparison(expression, term, default:)
      ["#{expression} #{operator(term, default: default)} ?", numeric_bind(term.value)]
    end

    # A whole number binds as an Integer, not a Float. edhrec_rank is an integer column, and binding 8000.0
    # against it makes Postgres try to read the literal "8000.0" as an integer and raise - so `rank>8000`
    # and `edhrec>8000` were errors, not empty results. Decimal columns (mana_value, prices) are unaffected
    # either way, and casting the column instead would have cost the edhrec_rank index.
    def numeric_bind(value)
      value.to_s.match?(/\A-?\d+\z/) ? value.to_i : value.to_f
    end

    def operator(term, default:)
      COMPARISONS.include?(term.op) ? term.op : default
    end

    # a leading `-` is handled by maybe_negate, so this only reads the value
    def subquery(join_table, lookup_table, foreign_key, match)
      "magic_cards.id IN (
         SELECT #{join_table}.magic_card_id FROM #{join_table}
         INNER JOIN #{lookup_table} ON #{lookup_table}.id = #{join_table}.#{foreign_key}
         WHERE #{match}
       )".squish
    end

    # a card name with a % or _ in it shouldn't turn into a wildcard
    def sanitize_like(value)
      ActiveRecord::Base.sanitize_sql_like(value)
    end
  end
end
