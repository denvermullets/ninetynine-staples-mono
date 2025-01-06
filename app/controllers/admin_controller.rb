class AdminController < ApplicationController
  before_action :authenticate_admin!

  private

  def authenticate_admin!
    return if current_user&.role.to_i == 9001

    render plain: 'Unauthorized', status: :unauthorized
  end
end
