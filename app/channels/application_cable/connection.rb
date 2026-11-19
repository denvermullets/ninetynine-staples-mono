# Two kinds of client share /cable. A native game client authenticates with the same bearer token the REST
# API uses; it can't set an Origin, so the global request-forgery origin check is disabled
# (config/initializers/action_cable.rb) and the token is its only gate. A browser can't set an
# Authorization header on a websocket, so it authenticates with its session cookie instead - and because a
# cookie rides along on any site's request, that path checks the Origin itself.
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # the token identifies a game client's socket, so revoking it can address exactly its sockets;
    # session_user identifies a browser's
    identified_by :api_token, :session_user

    # remote_connections needs every identifier; a token socket's session_user is always nil
    def self.disconnect_token(api_token)
      ActionCable.server.remote_connections.where(api_token: api_token, session_user: nil).disconnect
    end

    def connect
      bearer_token ? connect_with_token : connect_with_session
    end

    def current_user = api_token&.user || session_user

    # true once the socket has closed, which is how a channel tells a drop from an explicit unsubscribe
    def closing? = @closing == true

    def handle_close
      @closing = true
      super
    end

    private

    def connect_with_token
      token = ApiToken.find_active(bearer_token)
      reject_unauthorized_connection unless token

      token.touch_last_used!
      self.api_token = token
    end

    def connect_with_session
      reject_unauthorized_connection unless same_origin?

      user = User.find_by(id: session_user_id) if session_user_id
      reject_unauthorized_connection unless user

      self.session_user = user
    end

    def bearer_token
      request.authorization.to_s[/\ABearer (\S+)\z/, 1]
    end

    # the session is the app's cookie store; the cookie is only sent back to this host, but any page can
    # open a socket here and have it attached, so the page has to be one of ours
    def session_user_id
      cookies.encrypted[Rails.application.config.session_options[:key]]&.dig('user_id')
    end

    def same_origin?
      origin = request.origin
      origin.present? && URI.parse(origin).host == request.host
    rescue URI::InvalidURIError
      false
    end
  end
end
