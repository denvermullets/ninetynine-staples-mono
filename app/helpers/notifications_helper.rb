# Wording and links for in-app notifications - the toast, the list, and the nav badges.
module NotificationsHelper
  # One sentence per Notification kind. %<actor>s is whoever caused it, as notification_actor works out;
  # every other argument comes from the notification's payload.
  TEXT = {
    'trade_proposed' => '%<actor>s proposed a trade to you.',
    'trade_countered' => '%<actor>s countered your trade.',
    'trade_accepted' => '%<actor>s accepted your trade.',
    'trade_declined' => '%<actor>s declined your trade.',
    'trade_cancelled' => '%<actor>s cancelled your trade.',
    'trade_completed' => 'Your trade with %<actor>s is complete.',
    'price_threshold_crossed' => '%<card>s went %<direction>s %<threshold>s (now %<price>s).',
    'price_movement' => '%<subject>s moved %<summary>s %<window>s.'
  }.freeze

  # format raises on a missing key and ignores extra ones, so the payload goes in whole
  def notification_text(notification)
    format(TEXT.fetch(notification.kind), **notification.payload.symbolize_keys,
                                          actor: notification_actor(notification))
  end

  # Where reading a notification takes you: the record it is about, when that has a page of its own.
  # A deleted alert has nowhere to go, but its payload still says what happened.
  def notification_target_path(notification)
    case notification.notifiable
    when Trade then trade_path(notification.notifiable)
    when PriceAlert then price_alert_target_path(notification.notifiable)
    else notifications_path
    end
  end

  # Unread count for a nav badge: every notification, or only those about one notifiable type. The nav
  # draws each badge twice (desktop and mobile), so each count is only queried once per request.
  def unread_notifications_count(notifiable_type = nil)
    @unread_notifications_counts ||= {}
    @unread_notifications_counts[notifiable_type] ||= begin
      unread = current_user.notifications.unread
      notifiable_type ? unread.where(notifiable_type: notifiable_type).count : unread.count
    end
  end

  # the name a badge answers to - see Notifications::Deliver
  def unread_badge(notifiable_type = nil)
    name = notifiable_type || 'all'
    tag.span(render('notifications/unread_count', count: unread_notifications_count(notifiable_type)),
             data: { unread_badge: name })
  end

  private

  # A movement rule opens the movers page filtered the way the rule counted. A single printing has no
  # page of its own, so it opens its set as the user's collection sees it; an oracle alert watches a
  # want, so it opens the want list.
  def price_alert_target_path(alert)
    username = alert.user.username
    if alert.movement_rule?
      collection_movers_path(username, collection_id: alert.collection_id, **alert.movers_filters)
    elsif alert.magic_card&.boxset
      collection_set_path(username, alert.magic_card.boxset.code)
    elsif alert.scryfall_oracle_id.present?
      collection_wants_path(username)
    else
      notifications_path
    end
  end

  # the other party is the one who acted - the user being notified never notifies themselves
  def notification_actor(notification)
    case notification.notifiable
    when Trade then notification.notifiable.counterparty(notification.user)&.username || 'A former user'
    else 'Someone'
    end
  end
end
