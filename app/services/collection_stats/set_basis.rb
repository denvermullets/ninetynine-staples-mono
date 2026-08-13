# What "the set" means when you measure a collection against one.
#
# Two things ask that question - the completion panel, which ranks every set the collection touches,
# and the set detail page, which drills into one of them. They have to agree: a row that reads 87%
# on the panel and 91% on the page you reach by clicking it is worse than either number alone. So the
# definitions live here rather than in whichever of the two was written first.
module CollectionStats
  module SetBasis
    # Collector numbers are strings because plenty of them are not numbers - 1a, 12b, 297s. The
    # digits are what places a card in the set, so everything that has to order or bracket a printing
    # reads it through here and gets a NULL for a number with no digits in it at all.
    CARD_NUMBER_INT = "NULLIF(regexp_replace(magic_cards.card_number, '[^0-9]', '', 'g'), '')::int".freeze

    # Collectors mean the numbered run when they say "set completion" - Bloomburrow is 281 cards, not
    # the 397 you get once showcase, borderless and promo printings are counted. The run is recovered
    # from the collector number rather than trusted from base_set_size so it stays consistent with the
    # rows being counted; it reproduces base_set_size exactly on every set spot-checked.
    IN_BASE = "#{CARD_NUMBER_INT} <= boxsets.base_set_size".freeze

    # Some sets have no meaningful numbered run: Secret Lair Drop declares a base_set_size of 1
    # against 2,364 printings, and the Commander decks declare only their new cards. Measuring those
    # against their "base set" would report a collection of 26 Secret Lairs as 0% of one card, so a
    # run that small is treated as no run at all and the set is measured across every printing.
    BASE_RUN_MIN_SHARE = 0.5

    # A card is something you can collect if it is not a token and not the back face of a double-faced
    # card. That is the same definition the boxset browser uses (BoxsetsController#search_magic_cards),
    # and counting it this way rather than reading boxsets.total_set_size is what lets a set reach
    # exactly 100%: numerator and denominator are the same rows.
    PRINTABLE = "magic_cards.card_side IS NULL OR magic_cards.card_side = 'a'".freeze

    # PROXIES ARE NOT COLLECTED. Completion asks what you still have to acquire, and a proxy is the
    # thing you print *because* you have not acquired it - counting it as owned tells you a set is
    # finished when the missing column is exactly the list you would still have to buy.
    #
    # It rides on the join rather than sitting in the counts, so a proxy-only row never reaches the
    # aggregate at all: the printing goes back to being a null on the LEFT JOIN, exactly like one
    # nobody owns.
    REAL_COPIES = "#{Sql::REAL_QTY} > 0".freeze

    private

    def base_run?(total_base, total_all)
      total_base.positive? && total_base >= total_all * BASE_RUN_MIN_SHARE
    end

    def headline(owned, total)
      { owned: owned, total: total, missing: total - owned, share: share(owned, total) }
    end
  end
end
