# Bearer-token auth for /api/v1. Included by Api::V1::BaseController, so every endpoint requires a
# token unless it skips :authenticate_api_user!
module Api::TokenAuthentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_user!
  end

  def current_api_token
    @current_api_token
  end

  def current_api_user
    current_api_token&.user
  end

  private

  def authenticate_api_user!
    token = ApiToken.find_active(bearer_token)
    unless token
      response.headers['WWW-Authenticate'] = 'Bearer'
      return render_error(:unauthorized, 'unauthorized', 'Missing, invalid, revoked or expired token')
    end

    token.touch_last_used!
    @current_api_token = token
  end

  def bearer_token
    request.authorization.to_s[/\ABearer (\S+)\z/, 1]
  end
end
