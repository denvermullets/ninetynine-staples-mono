# The sets this collection has a real card from, for the set page's picker.
#
# Deliberately the cheapest form of the question. SetCompletion answers it too, as a by-product of
# scanning every card in every set the viewer touches, and reusing that here would put a full
# completion sweep on every page load and every filter toggle to populate a dropdown. This is one
# DISTINCT over collection_magic_cards, which is what a list of set names actually costs.
#
# Same membership rule as the completion panel: real copies only, no staged rows, no wishlist. A set
# you hold entirely in proxies does not appear, because the panel it is navigating between does not
# list it either - a picker offering sets the completion list does not have would be a dead end.
#
# The rule is Sql::REAL_ROW, the per-row form, rather than SetBasis::REAL_COPIES, which reads a
# summed CTE. Same answer for this question: a printing with a real copy in any collection puts its
# set in the list either way, and the set is what is being asked for.
module CollectionStats
  class OwnedSets < Base
    # Newest first. A collector opening a set picker is usually going somewhere recent, and it is
    # the order the sets were lived through.
    ORDER = 'boxsets.release_date DESC NULLS LAST, boxsets.name ASC'.freeze

    def call
      return Boxset.none if no_collections?

      Boxset.where(id: boxset_ids).order(Arel.sql(ORDER))
    end

    private

    def boxset_ids
      MagicCard
        .joins(:collection_magic_cards)
        .where(collection_magic_cards: { collection_id: @collection_ids,
                                         staged: false, needed: false })
        .where(Sql::REAL_ROW)
        .distinct
        .select(:boxset_id)
    end
  end
end
