#
# the vocabulary of the advanced search: every key the parser recognizes, and how the
# builder should turn it into SQL
#
# This is the only place a column name, table name or enum value is allowed to come from.
# Values typed by the user are always bound as parameters - nothing from params is ever
# interpolated into SQL, which is what keeps the whole feature injection-safe. Adding a new
# searchable field should mean adding one entry here plus a handler branch in Builder.
#
# :kind decides which of the three predicate shapes the builder emits:
#   :card  -> where(id: <subquery>) or a plain where on magic_cards - safe on a grouped relation
#   :price -> plain where on magic_cards price columns
#   :owned -> having(...) over the SUM aggregates Search::Collection already selected
#
module CardQuery
  module FieldRegistry
    RARITY_ORDER = %w[common uncommon rare mythic].freeze

    IS_FLAGS = %w[commander brawlcommander oathbreaker token reprint reserved dfc colorless foil
                  etched].freeze

    FIELDS = {
      # --- colors -------------------------------------------------------------------
      'c' => { handler: :color_set, kind: :card, join_table: 'magic_card_colors', default_op: '>=' },
      'color' => { handler: :color_set, kind: :card, join_table: 'magic_card_colors', default_op: '>=' },
      'colors' => { handler: :color_set, kind: :card, join_table: 'magic_card_colors', default_op: '>=' },
      'id' => { handler: :color_set, kind: :card, join_table: 'magic_card_color_idents', default_op: '<=' },
      'ci' => { handler: :color_set, kind: :card, join_table: 'magic_card_color_idents', default_op: '<=' },
      'identity' => { handler: :color_set, kind: :card, join_table: 'magic_card_color_idents', default_op: '<=' },

      # --- types ---------------------------------------------------------------------
      # spread across three normalized tables - see TypePredicate::TABLES
      't' => { handler: :type, kind: :card },
      'type' => { handler: :type, kind: :card },

      # --- text-ish columns on magic_cards ------------------------------------------
      'o' => { handler: :ilike, kind: :card, column: 'text' },
      'oracle' => { handler: :ilike, kind: :card, column: 'text' },
      'n' => { handler: :ilike, kind: :card, column: 'name' },
      'name' => { handler: :ilike, kind: :card, column: 'name' },
      'm' => { handler: :ilike, kind: :card, column: 'mana_cost' },
      'mana' => { handler: :ilike, kind: :card, column: 'mana_cost' },
      'ft' => { handler: :ilike, kind: :card, column: 'flavor_text' },
      'flavor' => { handler: :ilike, kind: :card, column: 'flavor_text' },
      'layout' => { handler: :ilike, kind: :card, column: 'layout' },
      'border' => { handler: :ilike, kind: :card, column: 'border_color' },

      # --- rarity (ordinal over a varchar) ------------------------------------------
      'r' => { handler: :rarity, kind: :card },
      'rarity' => { handler: :rarity, kind: :card },

      # --- numerics ------------------------------------------------------------------
      'mv' => { handler: :numeric, kind: :card, column: 'mana_value', default_op: '=' },
      'cmc' => { handler: :numeric, kind: :card, column: 'mana_value', default_op: '=' },
      'rank' => { handler: :numeric, kind: :card, column: 'edhrec_rank', default_op: '=' },
      'edhrec' => { handler: :numeric, kind: :card, column: 'edhrec_rank', default_op: '=' },
      'salt' => { handler: :numeric, kind: :card, column: 'edhrec_saltiness', default_op: '=' },

      # power/toughness are varchar and can hold "*" or "1+*" - the builder casts defensively
      'pow' => { handler: :numeric_cast, kind: :card, column: 'power', default_op: '=' },
      'power' => { handler: :numeric_cast, kind: :card, column: 'power', default_op: '=' },
      'tou' => { handler: :numeric_cast, kind: :card, column: 'toughness', default_op: '=' },
      'toughness' => { handler: :numeric_cast, kind: :card, column: 'toughness', default_op: '=' },

      # --- set ------------------------------------------------------------------------
      's' => { handler: :set_code, kind: :card },
      'set' => { handler: :set_code, kind: :card },
      'e' => { handler: :set_code, kind: :card },
      'edition' => { handler: :set_code, kind: :card },

      # --- associations ----------------------------------------------------------------
      'kw' => { handler: :assoc, kind: :card, join_table: 'magic_card_keywords',
                lookup_table: 'keywords', fk: 'keyword_id', lookup_column: 'keyword' },
      'keyword' => { handler: :assoc, kind: :card, join_table: 'magic_card_keywords',
                     lookup_table: 'keywords', fk: 'keyword_id', lookup_column: 'keyword' },
      'a' => { handler: :assoc, kind: :card, join_table: 'magic_card_artists',
               lookup_table: 'artists', fk: 'artist_id', lookup_column: 'name' },
      'artist' => { handler: :assoc, kind: :card, join_table: 'magic_card_artists',
                    lookup_table: 'artists', fk: 'artist_id', lookup_column: 'name' },
      'finish' => { handler: :assoc, kind: :card, join_table: 'magic_card_finishes',
                    lookup_table: 'finishes', fk: 'finish_id', lookup_column: 'name', exact: true },
      'frame' => { handler: :assoc, kind: :card, join_table: 'magic_card_frame_effects',
                   lookup_table: 'frame_effects', fk: 'frame_effect_id', lookup_column: 'name' },

      # --- card roles ----------------------------------------------------------------------
      # card_roles is keyed by scryfall_oracle_id rather than magic_card_id, so these cannot use the
      # :assoc shape - see Builder#predicate_for_card_role
      'role' => { handler: :card_role, kind: :card, column: 'role' },
      'effect' => { handler: :card_role, kind: :card, column: 'effect' },

      # --- commander colour identity ---------------------------------------------------------
      # takes a commander's name and resolves it to that commander's identity
      'commander' => { handler: :commander_identity, kind: :card },

      # --- format legality ---------------------------------------------------------------
      'f' => { handler: :legality, kind: :card, status: 'Legal' },
      'format' => { handler: :legality, kind: :card, status: 'Legal' },
      'legal' => { handler: :legality, kind: :card, status: 'Legal' },
      'banned' => { handler: :legality, kind: :card, status: 'Banned' },
      'restricted' => { handler: :legality, kind: :card, status: 'Restricted' },

      # --- boolean-ish card flags ---------------------------------------------------------
      'is' => { handler: :flag, kind: :card, values: IS_FLAGS },

      # --- prices --------------------------------------------------------------------------
      'usd' => { handler: :price, kind: :price, column: 'normal_price', default_op: '>=' },
      'price' => { handler: :price, kind: :price, column: 'normal_price', default_op: '>=' },
      'foilusd' => { handler: :price, kind: :price, column: 'foil_price', default_op: '>=' },
      'buylist' => { handler: :price, kind: :price, column: 'ck_buylist_normal_price', default_op: '>=' },
      'change' => { handler: :price_change, kind: :price, default_op: '>=' },

      # --- ownership (aggregate HAVING) ------------------------------------------------------
      'qty' => { handler: :owned_qty, kind: :owned, default_op: '>=' },
      'quantity' => { handler: :owned_qty, kind: :owned, default_op: '>=' },
      'foil' => { handler: :owned_flag, kind: :owned, columns: %w[foil_quantity] },
      'proxy' => { handler: :owned_flag, kind: :owned, columns: %w[proxy_quantity proxy_foil_quantity] },
      'needed' => { handler: :owned_needed, kind: :owned }
    }.freeze

    KEYS = FIELDS.keys.to_set.freeze

    def self.[](key) = FIELDS[key.to_s.downcase]

    def self.known?(key) = KEYS.include?(key.to_s.downcase)
  end
end
