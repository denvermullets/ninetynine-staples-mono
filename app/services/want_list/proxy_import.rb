# Puts the proxies a user is holding onto their want list, for the collector who is slowly swapping
# proxies out for the real thing.
#
# CollectionStats::ProxyRows finds the proxies, across every collection the user has, decks included.
# Its rows are per printing; a want is per card, so they are folded by oracle id here, and the quantity
# wanted is the number of proxies held. Real copies the user owns are deliberately not subtracted: a
# real copy in one deck says nothing about whether the proxy in another is one they want replaced, and
# that call is theirs to make from the list.
#
# A card already on the want list is left as it was, so pressing the button twice adds nothing, and it
# is not reported back - unlike a paste, there is no line of the user's to account for.
#
# A proxied printing with no oracle id is skipped: an any-printing want has nothing to match it on.
module WantList
  class ProxyImport < Service
    def initialize(user:)
      @user = user
    end

    def call
      result = AddByOracle.call(user: @user, quantities: quantities)

      { success: true, added: result[:added], already_wanted: [], ambiguous: [], unresolved: [] }
    end

    private

    def quantities
      rows = CollectionStats::ProxyRows.call(proxy_collection_ids: @user.collection_ids)

      rows.select { |row| row[:oracle_id].present? }.each_with_object(Hash.new(0)) do |row, totals|
        totals[row[:oracle_id]] += row[:proxy_qty] + row[:proxy_foil_qty]
      end
    end
  end
end
