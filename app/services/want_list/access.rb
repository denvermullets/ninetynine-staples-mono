# Whether the viewer may look at a user's want list, and which of that user's collections the page
# is allowed to check the wants against.
#
# A service for the same reason CollectionTrades::Access is one: the visibility rules are the part
# worth testing, and a request spec that gets past them renders a layout CI cannot build.
#
# The owner always sees their own list. Everyone else, logged out included, needs users.wants_public -
# the same all-or-nothing rule a private collection gets. The collection ids come from
# CollectionStats::Scope, so a visitor's "now owned" column only counts copies in collections they
# could open anyway: a public want list never gives away what is in a private binder.
module WantList
  class Access < Service
    def initialize(username:, viewer: nil)
      @username = username
      @viewer = viewer
    end

    def call
      scope = CollectionStats::Scope.call(username: @username, viewer: @viewer)
      user = scope[:user]

      { user: user, owner: scope[:owner], visible: scope[:owner] || user.wants_public?,
        collection_ids: scope[:collection_ids] }
    end
  end
end
