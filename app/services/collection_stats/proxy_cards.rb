# The proxies you hold, and whether the real card is already sitting somewhere in your collections.
#
# Every other surface in here subtracts proxies - SetBasis::REAL_COPIES keeps them out of completion,
# Sql keeps them out of every value figure, the collection browse hides them by default. This is the
# one that puts them BACK, because a proxy pile raises a question none of those can answer: which of
# these have I quietly bought the real one for since, and which are still a line on the shopping list?
#
# Finding the rows is CollectionStats::ProxyRows. This is the layer on top: the page's two toggles,
# and the numbers printed on them.
#
# TWO AXES, NOT ONE LIST OF BUTTONS. "Is the real card somewhere" and "is this proxy sleeved in a
# deck" are independent questions, and the useful answer is usually the crossing of them - the cards
# you are playing with that you have never actually bought. Flattening them into a single filter
# would make that unaskable. Same shape as the set page carrying its view alongside its filter.
module CollectionStats
  class ProxyCards < Service
    FILTERS = %w[all proxy_only other_printing].freeze

    LOCATIONS = %w[all decks binders swappable].freeze

    EMPTY = { rows: [],
              counts: { all: 0, proxy_only: 0, other_printing: 0 },
              location_counts: { all: 0, decks: 0, binders: 0, swappable: 0 },
              totals: { copies: 0, printings: 0, proxy_only: 0, value: 0, cost_to_replace: 0 } }.freeze

    def initialize(proxy_collection_ids:, search_collection_ids: nil, filter: 'all', location: 'all')
      @proxy_collection_ids = proxy_collection_ids
      @search_collection_ids = search_collection_ids
      @filter = FILTERS.include?(filter.to_s) ? filter.to_s : 'all'
      @location = LOCATIONS.include?(location.to_s) ? location.to_s : 'all'
    end

    # Each toggle is counted against the OTHER axis, not against everything. A reader looking at the
    # deck proxies wants "and how many of those have no real copy" - counting all four buttons over
    # the whole pile would label them with numbers that do not match the list underneath them the
    # moment either axis is off all.
    #
    # totals stay over every row on purpose: the summary tiles sit outside the turbo frame, so they
    # do not re-render when a toggle moves and must not describe something the toggles can change.
    def call
      rows = ProxyRows.call(proxy_collection_ids: @proxy_collection_ids,
                            search_collection_ids: @search_collection_ids)
      return EMPTY if rows.empty?

      { rows: rows.select { |row| keep?(row) && in_location?(row) },
        counts: counts(rows.select { |row| in_location?(row) }),
        location_counts: location_counts(rows.select { |row| keep?(row) }),
        totals: totals(rows) }
    end

    private

    # There is deliberately no "real owned" button. It would be the exact complement of proxy_only -
    # has_real and !has_real partition the rows - so it could only ever list what the shopping list
    # leaves out, and its count is `all` minus that one. Every button here has to produce a set the
    # others cannot reconstruct, and that one could not.
    #
    # other_printing survives that test: it is a SUBSET of the backed rows, not their whole, and it
    # asks something the count cannot answer - which of these do I own in a version I did not sleeve.
    def keep?(row)
      case @filter
      when 'proxy_only' then !row[:has_real]
      when 'other_printing' then row[:real_other_printing]
      else true
      end
    end

    # decks and binders OVERLAP too, and for the same reason the status filters do. A printing you
    # proxied four times - three sleeved in a deck, one spare in a binder - is genuinely both, and a
    # row is a printing rather than a copy, so forcing it to pick a side would hide it from whichever
    # list you happened to open. Deck-ness is asked of the PROXY locations only: where the real card
    # lives is the other axis's question.
    # swappable lives on this axis rather than beside the real-copy filters because it is a narrowing
    # of `decks`, not a statement about the real copy on its own: every swap-ready row is a deck row.
    # Sitting it here also removes a combination that could only ever be empty - swap-ready proxies
    # OUTSIDE a deck do not exist, and a button pair that can contradict each other invites the click.
    def in_location?(row)
      case @location
      when 'decks' then row[:in_deck]
      when 'binders' then row[:outside_deck]
      when 'swappable' then row[:swappable]
      else true
      end
    end

    # Counted off the rows the other axis left standing rather than off the filtered list, so every
    # button can be labelled from the one pass the page already paid for.
    def counts(rows)
      { all: rows.size,
        proxy_only: rows.count { |row| !row[:has_real] },
        other_printing: rows.count { |row| row[:real_other_printing] } }
    end

    def location_counts(rows)
      { all: rows.size,
        decks: rows.count { |row| row[:in_deck] },
        binders: rows.count { |row| row[:outside_deck] },
        swappable: rows.count { |row| row[:swappable] } }
    end

    # Notional, and the tile says so. Sql explains why no other figure on the dashboard prices a
    # proxy: it is cardstock you printed, and valuing it at what the real card sells for inflates
    # every money number by whatever your proxy pile would cost to buy. Here that number IS the
    # question - what the pile would cost to make real - so it gets computed, off the same
    # PROXY_NORMAL/PROXY_FOIL fallback rule, and kept on this page.
    def totals(rows)
      { copies: rows.sum { |row| row[:proxy_qty] + row[:proxy_foil_qty] },
        printings: rows.size,
        proxy_only: rows.count { |row| !row[:has_real] },
        value: money(rows.sum { |row| proxy_value(row) }),
        cost_to_replace: money(rows.reject { |row| row[:has_real] }.sum { |row| proxy_value(row) }) }
    end

    # Ruby rather than a third aggregate: the rows are already in memory and bounded by the proxies
    # you hold. Mirrors MagicCard#proxy_normal_price - a proxy of a foil-only printing still has to
    # price off something, so each finish falls back to the other.
    def proxy_value(row)
      normal = row[:normal_price].to_d
      foil = row[:foil_price].to_d

      (row[:proxy_qty] * (normal.positive? ? normal : foil)) +
        (row[:proxy_foil_qty] * (foil.positive? ? foil : normal))
    end

    def money(value)
      value.to_d.round(2)
    end
  end
end
