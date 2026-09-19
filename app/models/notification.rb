# Something a user should hear about, kept until they have read it.
#
# Nothing here knows about any one feature. `kind` names what happened and `notifiable` points at the
# record it happened to, so trades today and deck jobs later all write the same row. Written only by
# Notifications::Deliver, which also pushes the toast and the nav badge counts.
#
# A new kind needs an entry in KINDS and a sentence in NotificationsHelper::TEXT, and, if its
# notifiable has a page, a branch in NotificationsHelper#notification_target_path.
class Notification < ApplicationRecord
  KINDS = %w[trade_proposed trade_countered trade_accepted trade_declined trade_cancelled trade_completed].freeze

  belongs_to :user
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }

  scope :unread, -> { where(read_at: nil) }
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :about, ->(notifiable) { where(notifiable: notifiable) }

  def self.mark_all_read!
    unread.update_all(read_at: Time.current)
  end

  def read?
    read_at.present?
  end

  def mark_read!
    update!(read_at: Time.current) unless read?
  end
end
