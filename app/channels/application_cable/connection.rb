# Authenticates a game client's websocket with the same bearer token the REST API uses. Native
# clients can't set an Origin and don't authenticate by cookie, so the request-forgery origin check
# is disabled (config/initializers/action_cable.rb) and the token is the only gate
module ApplicationCable
  class Connection < ActionCable::Connection::Base
    # the token is the only identifier, so revoking it can address exactly its sockets
    identified_by :api_token

    delegate :user, to: :api_token, prefix: :current

    def self.disconnect_token(api_token)
      ActionCable.server.remote_connections.where(api_token: api_token).disconnect
    end

    def connect
      token = ApiToken.find_active(bearer_token)
      reject_unauthorized_connection unless token

      token.touch_last_used!
      self.api_token = token
    end

    # true once the socket has closed, which is how a channel tells a drop from an explicit unsubscribe
    def closing? = @closing == true

    def handle_close
      @closing = true
      super
    end

    private

    def bearer_token
      request.authorization.to_s[/\ABearer (\S+)\z/, 1]
    end
  end
end
