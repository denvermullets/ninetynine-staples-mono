module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    # channels get the connection's identifiers (api_token for a game client, session_user for a
    # browser - ApplicationCable::Connection), not its own helpers, so the user is read through them here
    def current_user
      @current_user ||= api_token&.user || session_user
    end
  end
end
