# Finding the proxies you hold and the real cards behind them. What the page then DOES with those
# rows - the status filter, the deck filter, the counts under each button - is CollectionStats::ProxyCards.
#
# A ROW IS A PRINTING, not a card. You proxied a specific version and that is the piece of cardstock
# in the sleeve, so a proxied Alpha Underground Sea and a proxied Revised one are two rows. The
# real-copy lookup is the part that reaches ACROSS printings, by scryfall_oracle_id, which is what
# lets a row say "you own this for real, just not in this printing" - the most useful thing the page
# has to say and the one a per-printing match would miss.
#
# TWO SCOPES, NOT ONE, and they are deliberately different. The collection picker narrows which
# proxies are LISTED; it never narrows where real copies are looked FOR. Searching one collection for
# both would report "proxy only" for a card whose real copy is in the binder next door, which is
# precisely the finding somebody opens this page for.
#
# Two queries, then Ruby, the same shape as SetCards. Grouping in SQL would mean array_agg over a
# wider GROUP BY to carry each location's collection out, and the row count is bounded by the proxies
# you own rather than by the card table, so there is nothing to win and a lot of legibility to lose.
module CollectionStats
  class ProxyRows < Service
    include CollectionStats::Sql

    # Both queries pluck the same shape so one row builder serves them. collections.id/name ride
    # along because WHICH BINDER is the question - rolling them up is what Base's `owned` CTE does,
    # and it is exactly the information this page cannot lose.
    CARD_COLUMNS = [
      'magic_cards.id', 'magic_cards.name', 'magic_cards.card_number', 'magic_cards.rarity',
      'magic_cards.image_medium', 'magic_cards.image_large',
      'magic_cards.normal_price', 'magic_cards.foil_price',
      'magic_cards.scryfall_oracle_id::text',
      'boxsets.name', 'boxsets.code', 'boxsets.keyrune_code',
      'collections.id', 'collections.name', 'collections.collection_type'
    ].freeze

    PROXY_COLUMNS = (CARD_COLUMNS + ['collection_magic_cards.proxy_quantity',
                                     'collection_magic_cards.proxy_foil_quantity']).freeze

    REAL_COLUMNS = (CARD_COLUMNS + ['collection_magic_cards.quantity',
                                    'collection_magic_cards.foil_quantity']).freeze

    def initialize(proxy_collection_ids:, search_collection_ids: nil)
      @proxy_collection_ids = Array(proxy_collection_ids).compact
      @search_collection_ids = Array(search_collection_ids || proxy_collection_ids).compact
    end

    def call
      build_rows
    end

    private

    def build_rows
      proxies = fetch_proxies
      return [] if proxies.empty?

      real = real_locations_by_key(proxies)

      proxies.group_by { |row| row[:id] }
             .map { |id, locations| card_row(id, locations, real) }
             .sort_by { |row| [row[:name].to_s.downcase, row[:set_code].to_s, row[:number].to_s] }
    end

    # staged and needed match Base#owned_rows: staged rows are deck-builder scratch and needed rows
    # are wishlist, and neither is a proxy you are holding.
    def fetch_proxies
      fetch(CollectionMagicCard.where(collection_id: @proxy_collection_ids).where(PROXY_ROW),
            PROXY_COLUMNS)
    end

    # card_side is the one filter this side needs that the proxy side does not. Back faces carry the
    # same oracle id as their front, so without it the b-face row of a double-faced card matches the
    # oracle key and reads as a real copy nobody owns. Same guard MagicCard#other_printing_locations
    # uses, for the same reason.
    def fetch_real(oracle_ids, names)
      scope = CollectionMagicCard.where(collection_id: @search_collection_ids)
                                 .where(REAL_ROW)
                                 .where(magic_cards: { card_side: [nil, 'a'] })

      fetch(scope.where(*key_clause(oracle_ids, names)), REAL_COLUMNS)
    end

    def fetch(scope, columns)
      scope.joins(:collection).joins(magic_card: :boxset)
           .where(staged: false, needed: false)
           .pluck(*columns.map { |column| Arel.sql(column) })
           .map { |row| location(row) }
    end

    # Only the halves that have something in them. `name IN ()` on an empty list is a WHERE that can
    # never be true, which would silently drop every real copy the moment every proxied printing had
    # its oracle id backfilled.
    def key_clause(oracle_ids, names)
      clauses = []
      clauses << ['magic_cards.scryfall_oracle_id IN (?)', oracle_ids] if oracle_ids.any?
      clauses << ['magic_cards.name IN (?)', names] if names.any?

      [clauses.map(&:first).join(' OR '), *clauses.map(&:last)]
    end

    def real_locations_by_key(proxies)
      cards = proxies.uniq { |row| row[:id] }
      oracle_ids = cards.filter_map { |row| row[:oracle_id].presence }.uniq
      names = unbackfilled_names(cards)
      return {} if oracle_ids.empty? && names.empty?

      fetch_real(oracle_ids, names).group_by { |row| key_for(row) }
    end

    def unbackfilled_names(cards)
      cards.reject { |row| row[:oracle_id].present? }
           .filter_map { |row| row[:name].presence }
           .uniq
    end

    def location(row)
      id, name, number, rarity, image, image_large, normal_price, foil_price, oracle_id,
        set_name, set_code, keyrune, collection_id, collection_name, collection_type,
        qty, foil_qty = row

      { id: id, name: name, number: number, rarity: rarity, image: image,
        image_large: image_large.presence || image, normal_price: normal_price,
        foil_price: foil_price, oracle_id: oracle_id, set_name: set_name, set_code: set_code,
        keyrune: keyrune, collection_id: collection_id, collection_name: collection_name,
        deck: Collection.deck_type?(collection_type), qty: qty.to_i, foil_qty: foil_qty.to_i }
    end

    # The same fallback ladder SetCards uses. scryfall_oracle_id is nullable and still being
    # backfilled, so a printing without one falls back to its name and then to its own id rather
    # than every unbackfilled card in the collection collapsing onto a single null key.
    def key_for(row)
      return "oracle:#{row[:oracle_id]}" if row[:oracle_id].present?
      return "name:#{row[:name]}" if row[:name].present?

      "id:#{row[:id]}"
    end

    def card_row(id, locations, real)
      card = locations.first
      proxy_locations = fold(locations)
      real_locations = fold(real.fetch(key_for(card), []))
                       .map { |row| row.merge(same_printing: row[:printing_id] == id) }

      card.slice(:id, :name, :number, :rarity, :image, :image_large, :normal_price, :foil_price,
                 :oracle_id, :set_name, :set_code, :keyrune)
          .merge(key: key_for(card), proxy_locations: proxy_locations,
                 real_locations: real_locations)
          .merge(quantities(proxy_locations, real_locations))
    end

    # collection_magic_cards has no unique index on (collection_id, magic_card_id), so the same
    # printing can be held on two rows in one binder - card_uuid is part of how they are found. Two
    # lines reading "Cube x1" and "Cube x1" is a data artefact, not a fact about the collection.
    def fold(locations)
      locations.group_by { |row| [row[:collection_id], row[:id]] }
               .map { |_, rows| merge_copies(rows) }
               .sort_by { |row| [row[:collection_name].to_s.downcase, row[:set_code].to_s] }
    end

    def merge_copies(rows)
      rows.first.merge(qty: rows.sum { |row| row[:qty] },
                       foil_qty: rows.sum { |row| row[:foil_qty] },
                       printing_id: rows.first[:id])
    end

    # same_printing and other_printing are both reported rather than one being derived from the
    # other, because a card can be BOTH: the real Revised copy in one binder and the real Alpha copy
    # in another are two different answers to "can I retire this proxy", and collapsing them to a
    # single flag loses the one that tells you which.
    def quantities(proxy_locations, real_locations)
      { proxy_qty: proxy_locations.sum { |row| row[:qty] },
        proxy_foil_qty: proxy_locations.sum { |row| row[:foil_qty] },
        real_qty: real_locations.sum { |row| row[:qty] },
        real_foil_qty: real_locations.sum { |row| row[:foil_qty] } }
        .merge(flags(proxy_locations, real_locations))
    end

    # Everything the toggles read, and nothing they do not. Every axis is asked as `any?` over the
    # locations rather than as a property of the row, because a row is a printing and a printing can
    # be in several places at once - which is what lets the same card be honestly both.
    def flags(proxy_locations, real_locations)
      real_flags(real_locations).merge(deck_flags(proxy_locations, real_locations))
    end

    def real_flags(real_locations)
      { has_real: real_locations.any?,
        real_same_printing: real_locations.any? { |row| row[:same_printing] },
        real_other_printing: real_locations.any? { |row| !row[:same_printing] } }
    end

    # SWAPPABLE IS THE ACTIONABLE ONE: a proxy sleeved in a deck whose real copy is sitting outside
    # every deck, so you can put the real card in without taking another deck apart to do it.
    #
    # It hangs on real_outside_deck rather than on has_real for exactly that reason. A real copy that
    # is already sleeved in a different deck is spoken for - counting it would fill the list with
    # swaps that cost you a hole somewhere else, which is the opposite of a list you can work through.
    # A real copy in the SAME deck as the proxy lands outside this too, and should: nothing to move.
    def deck_flags(proxy_locations, real_locations)
      in_deck = proxy_locations.any? { |row| row[:deck] }
      real_outside_deck = real_locations.any? { |row| !row[:deck] }

      { in_deck: in_deck,
        outside_deck: proxy_locations.any? { |row| !row[:deck] },
        real_in_deck: real_locations.any? { |row| row[:deck] },
        real_outside_deck: real_outside_deck,
        swappable: in_deck && real_outside_deck }
    end
  end
end
