# How many of the viewer's wants a user's trade list could fill - the "2 cards you want" badge a
# visitor sees on somebody else's trade list.
#
# The forward direction of WantList::Matches narrowed to that one holder, counting only the wants
# met by a marked copy: the badge sits on a trade list, so a card the holder owns but is not offering
# does not belong in it. The wants are the viewer's own, so their want list does not need to be public.
#
# Zero for a logged-out visitor and for the owner looking at their own list.
module WantList
  class TradeBadge < Service
    def initialize(viewer:, holder:)
      @viewer = viewer
      @holder = holder
    end

    def call
      return 0 if @viewer.nil? || @holder.nil? || @viewer.id == @holder.id

      Matches.call(user: @viewer, with: @holder, per_page: 1)[:users].first&.tradeable_count.to_i
    end
  end
end
