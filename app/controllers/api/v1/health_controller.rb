# The Godot client calls this on boot. Below min_client_version it shows a "please update" message
# instead of talking to endpoints that may have changed under it
class Api::V1::HealthController < Api::V1::BaseController
  MIN_CLIENT_VERSION = '0.1.0'.freeze

  def show
    render json: { status: 'ok', api_version: 'v1', min_client_version: MIN_CLIENT_VERSION }
  end
end
