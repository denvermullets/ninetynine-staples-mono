# The game client is a native app: it sends no Origin header and authenticates with a bearer token
# rather than a cookie, so Origin checks protect nothing here (ApplicationCable::Connection)
Rails.application.config.action_cable.disable_request_forgery_protection = true
