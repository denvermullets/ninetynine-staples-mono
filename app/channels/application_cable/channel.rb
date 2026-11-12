module ApplicationCable
  class Channel < ActionCable::Channel::Base
    private

    # the connection is identified by its api_token (ApplicationCable::Connection); channels get the
    # identifier, not the connection's own helpers, so the user is read through it here
    def current_user
      @current_user ||= api_token.user
    end
  end
end
