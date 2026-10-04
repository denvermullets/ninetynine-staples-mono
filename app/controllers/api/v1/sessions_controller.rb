# Password-grant login for the game client: email + password in, bearer token out. Mirrors the web
# login in Users::SessionsController, which does not require a confirmed email either
class Api::V1::SessionsController < Api::V1::BaseController
  DEFAULT_DEVICE_NAME = 'Game client'.freeze

  skip_before_action :authenticate_api_user!, only: :create

  def create
    user = User.find_by(email: params.require(:email))
    unless user&.authenticate(params.require(:password))
      return render_error(:unauthorized, 'invalid_credentials', 'Invalid email or password')
    end

    token, raw_token = ApiToken.issue!(user, name: device_name)
    render json: { token: raw_token, expires_at: token.expires_at, user: Api::V1::UserSerializer.new(user) },
           status: :created
  end

  # logs out this client only - other devices keep their tokens
  def destroy
    current_api_token.revoke!
    head :no_content
  end

  private

  def device_name
    params[:device_name].to_s.strip.truncate(100).presence || DEFAULT_DEVICE_NAME
  end
end
