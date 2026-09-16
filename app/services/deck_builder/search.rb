#
# the deck builder's add-card search, sharing the collections page's query language
#
# CardQuery::Parser splits the box into structured terms plus leftover free text, and
# CardQuery::Builder folds those terms onto both halves of this search - the rows you own
# (CollectionMagicCard joined to magic_cards) and the newest printing of anything matching.
# Builder's card-level predicates are all `magic_cards.id IN (...)` subqueries, so they compose
# onto either relation without adding a join.
#
# Ownership terms (qty:, foil:, proxy:, needed: - FieldRegistry kind: :owned) are the exception
# and are refused here rather than applied. They are HAVING clauses over SUM aggregates, which
# only mean anything on a relation grouped by magic_cards.id - and this panel deliberately keeps
# one row per collection so it can tell you which of your collections a copy is sitting in.
# The scope toggle ("My Collection") is how ownership is expressed here. Builder#apply_having
# would drop them silently, so they come back in `unsupported` for the panel to report instead.
#
module DeckBuilder
  class Search < Service
    CARD_TYPES = %i[regular foil proxy proxy_foil].freeze
    TYPE_LABELS = { regular: 'Regular', foil: 'Foil', proxy: 'Proxy', proxy_foil: 'Foil Proxy' }.freeze

    # A one-character name fragment matches most of the card pool, so it is not worth searching on.
    MIN_FREE_TEXT = 2

    # A row with no physical copies can never produce a result, and leaving it in would let it eat
    # one of the LIMIT slots below.
    HAS_COPIES = <<~SQL.squish.freeze
      COALESCE(collection_magic_cards.quantity, 0)
        + COALESCE(collection_magic_cards.foil_quantity, 0)
        + COALESCE(collection_magic_cards.proxy_quantity, 0)
        + COALESCE(collection_magic_cards.proxy_foil_quantity, 0) > 0
    SQL

    Result = Struct.new(:results, :card_query, :unsupported, keyword_init: true)

    def initialize(query:, user:, deck:, scope: 'all', limit: 20)
      @query = query
      @user = user
      @deck = deck
      @scope = scope
      @limit = limit
    end

    def call
      @card_query = CardQuery::Parser.call(query: @query)

      Result.new(results: results, card_query: @card_query, unsupported: unsupported.map(&:key).uniq)
    end

    private

    def results
      return [] unless searchable?

      @scope == 'owned' ? search_owned_only : search_all_cards
    end

    # `role:ramp` has no free text at all and is specific enough on its own, so the two-character
    # floor only applies to what is actually being matched against the card name.
    def searchable?
      supported.any? || @card_query.free_text.length >= MIN_FREE_TEXT
    end

    def unsupported = split_terms.first
    def supported = split_terms.last

    # the parser only ever emits keys the registry knows, so the lookup is always a hit
    def split_terms
      @split_terms ||= @card_query.terms.partition { |term| CardQuery::FieldRegistry[term.key][:kind] == :owned }
    end

    def search_all_cards
      results = build_owned_results

      results.concat(build_latest_results(@limit - results.size)) if results.size < @limit

      capped = results.first(@limit)
      append_browse_entries(capped)
      capped
    end

    def search_owned_only
      build_owned_results.first(@limit)
    end

    def build_owned_results
      owned_cards.flat_map { |cmc| results_for_card(cmc) }
    end

    # Limited in SQL rather than after the fact: an advanced query like `t:creature` matches most of
    # a collection, and every row surviving this costs a StagedQuantities round trip below. A row whose
    # copies are all staged into another deck still spends a slot, which is the price of not loading
    # the whole collection to find out.
    def owned_cards
      advanced(
        name_matching(
          CollectionMagicCard
            .joins(:collection, :magic_card)
            .includes(magic_card: :boxset, collection: [])
            .where(collections: { user_id: @user.id })
            .where.not(collection_id: @deck.id)
            .where(staged: false, needed: false)
            .where(magic_cards: { is_token: false })
            .where(HAS_COPIES)
        )
      ).order('magic_cards.name ASC').limit(@limit)
    end

    def results_for_card(cmc)
      quantities = calculate_available_quantities(cmc)
      base = build_base_result(cmc)

      CARD_TYPES.filter_map do |type|
        next unless quantities[type].positive?

        base.merge(card_type: type, available: quantities[type], type_label: TYPE_LABELS[type])
      end
    end

    def build_base_result(cmc)
      {
        type: :owned,
        card: cmc.magic_card,
        collection_magic_card_id: cmc.id,
        collection_id: cmc.collection_id,
        collection_name: cmc.collection.name,
        already_in_deck: already_in_deck?(cmc)
      }
    end

    def already_in_deck?(cmc)
      @deck.collection_magic_cards.exists?(
        magic_card_id: cmc.magic_card_id,
        source_collection_id: cmc.collection_id
      )
    end

    def build_latest_results(limit)
      MagicCard
        .where(id: newest_card_ids(limit))
        .includes(:boxset)
        .order(:name)
        .map { |card| build_latest_result(card) }
    end

    def newest_card_ids(limit)
      advanced(
        name_matching(
          MagicCard
            .joins(:boxset)
            .select('DISTINCT ON (magic_cards.name) magic_cards.id')
            .where(is_token: false)
        )
      ).order('magic_cards.name, boxsets.release_date DESC').limit(limit)
    end

    def build_latest_result(card)
      deck_card = @deck.collection_magic_cards.find_by(magic_card_id: card.id)
      {
        type: :latest,
        card: card,
        already_in_deck: deck_card.present?,
        deck_card_planned: deck_card&.planned?
      }
    end

    # viewer_id lets otag: see the tags this user added - the panel only ever searches their own
    # collections and their own deck.
    def advanced(cards)
      CardQuery::Builder.call(cards: cards, terms: supported, viewer_id: @user.id)
    end

    # A term-only query (`role:ramp mv<=3`) has nothing to match against the name, and an unconditional
    # `ILIKE '%%'` would just cost an index.
    def name_matching(cards)
      return cards if @card_query.free_text.blank?

      cards.where('magic_cards.name ILIKE ?', "%#{ActiveRecord::Base.sanitize_sql_like(@card_query.free_text)}%")
    end

    def append_browse_entries(results)
      card_names_with_latest = results.select { |r| r[:type] == :latest }.to_set { |r| r[:card].name }
      card_names_in_results = results.map { |r| r[:card].name }.uniq

      card_names_in_results.each do |name|
        next if card_names_with_latest.include?(name)

        card = newest_card_for_name(name)
        next unless card

        results << { type: :browse, card: card }
      end
    end

    def newest_card_for_name(name)
      MagicCard
        .joins(:boxset)
        .where(is_token: false, name: name)
        .order('boxsets.release_date DESC')
        .first
    end

    def calculate_available_quantities(cmc)
      staged = StagedQuantities.call(
        source_collection_id: cmc.collection_id,
        magic_card_id: cmc.magic_card_id
      )

      {
        regular: [cmc.quantity - staged[:regular], 0].max,
        foil: [cmc.foil_quantity - staged[:foil], 0].max,
        proxy: [(cmc.proxy_quantity || 0) - staged[:proxy], 0].max,
        proxy_foil: [(cmc.proxy_foil_quantity || 0) - staged[:proxy_foil], 0].max
      }
    end
  end
end
