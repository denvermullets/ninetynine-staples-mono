# Whether the viewer may look at a user's trade list.
#
# A service rather than a before_action for the same reason CollectionStats::Scope is one: the
# visibility rules are the part worth testing, and a request spec that gets past them renders a
# layout CI cannot build.
#
# The owner always sees their own list, so a private list can still be previewed before it is
# opened up. Everyone else, logged out included, needs users.trades_public - the same all-or-nothing
# rule a private collection gets from CollectionsController#enforce_visibility.
module CollectionTrades
  class Access < Service
    def initialize(username:, viewer: nil)
      @username = username
      @viewer = viewer
    end

    def call
      { user: user, owner: owner?, visible: owner? || user.trades_public? }
    end

    private

    # find_by! so an unknown username 404s the same way the other collection pages do
    def user
      @user ||= User.find_by!(username: @username)
    end

    def owner?
      @viewer&.id == user.id
    end
  end
end
