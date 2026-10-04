class Api::V1::MeController < Api::V1::BaseController
  def show
    render json: Api::V1::UserSerializer.new(current_api_user, preferences: true)
  end
end
