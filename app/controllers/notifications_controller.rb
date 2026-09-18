# The signed-in user's notifications. Everything is found through current_user.notifications, so
# someone else's notification is a 404.
class NotificationsController < ApplicationController
  PER_PAGE = 25

  before_action :authenticate_user!

  def index
    @unread_count = current_user.notifications.unread.count
    @pagy, @notifications = pagy(:offset, current_user.notifications.newest_first.includes(:user, :notifiable),
                                 limit: PER_PAGE)
  end

  # marks it read and goes on to whatever it is about
  def read
    notification = current_user.notifications.find_by(id: params[:id])
    return head :not_found if notification.nil?

    notification.mark_read!
    redirect_to helpers.notification_target_path(notification), status: :see_other
  end

  def read_all
    current_user.notifications.mark_all_read!
    redirect_to notifications_path, status: :see_other
  end
end
