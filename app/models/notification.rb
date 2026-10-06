# Something a user should hear about, kept until they have read it.
#
# Nothing here knows about any one feature. `kind` names what happened and `notifiable` points at the
# record it happened to, so trades today and deck jobs later all write the same row. Written only by
# Notifications::Deliver, which also pushes the toast and the nav badge counts.
#
# A new kind needs an entry in KINDS and a sentence in NotificationsHelper::TEXT, and, if its
# notifiable has a page, a branch in NotificationsHelper#notification_target_path.
#
# `payload` is whatever the sentence needs that the notifiable cannot be trusted to still say when
# the notification is read - a price alert's card and price on the day it fired. Its keys are format
# arguments for the kind's sentence.
class Notification < ApplicationRecord
  KINDS = %w[trade_proposed trade_countered trade_accepted trade_declined trade_cancelled trade_completed
             price_threshold_crossed price_movement price_band_crossed].freeze

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
