# Records a notification for `user` and tells any page they have open about it: a toast, and fresh
# counts for the unread badges in the nav.
#
# Safe to call inside a transaction - the row is written with it, and the broadcasts wait until the
# outermost transaction commits, so a rolled-back change never toasts about something that did not
# happen.
#
# Every nav badge is a `[data-unread-badge]` element. "all" counts every unread notification; a badge
# named after a notifiable type (e.g. "Trade") counts only the ones about that type.
module Notifications
  class Deliver < Service
    def initialize(user:, kind:, notifiable: nil)
      @user = user
      @kind = kind.to_s
      @notifiable = notifiable
    end

    def call
      notification = @user.notifications.create!(kind: @kind, notifiable: @notifiable)
      ActiveRecord.after_all_transactions_commit { broadcast(notification) }
      notification
    end

    private

    def stream
      "user_#{@user.id}_notifications"
    end

    def broadcast(notification)
      Turbo::StreamsChannel.broadcast_append_to(
        stream, target: 'toasts', partial: 'shared/broadcast_toast',
                locals: { message: ApplicationController.helpers.notification_text(notification), type: 'success' }
      )

      unread = @user.notifications.unread
      broadcast_badge('all', unread.count)
      broadcast_badge(notification.notifiable_type, unread.where(notifiable_type: notification.notifiable_type).count)
    end

    def broadcast_badge(name, count)
      return if name.nil?

      Turbo::StreamsChannel.broadcast_update_to(
        stream, targets: %([data-unread-badge="#{name}"]), partial: 'notifications/unread_count',
                locals: { count: count }
      )
    end
  end
end
