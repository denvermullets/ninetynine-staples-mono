module GameTracker
  class BaseController < ApplicationController
    before_action :set_user_from_username, if: :username_scoped_route?
    before_action :check_tracker_visibility, if: :username_scoped_route?

    helper_method :viewing_own_tracker?, :tracker_owner

    private

    def set_user_from_username
      @tracker_owner = User.find_by!(username: params[:username])
    rescue ActiveRecord::RecordNotFound
      redirect_to root_path, alert: 'User not found'
    end

    def check_tracker_visibility
      return if viewing_own_tracker?
      return if tracker_owner.game_tracker_public?

      redirect_to root_path, alert: 'This game tracker is private'
    end

    def viewing_own_tracker?
      logged_in? && current_user.id == tracker_owner&.id
    end

    def tracker_owner
      @tracker_owner || current_user
    end

    def username_scoped_route?
      params[:username].present?
    end

    def require_owner!
      return if viewing_own_tracker?

      redirect_to root_path, alert: 'Access denied'
    end
  end
end
