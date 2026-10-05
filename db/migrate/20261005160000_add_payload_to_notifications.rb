# What a notification has to say that its notifiable cannot tell you later: a price alert's card
# name, the price on the day it fired, how many cards moved. The alert may have changed or been
# deleted by the time the notification is read.
class AddPayloadToNotifications < ActiveRecord::Migration[8.1]
  def change
    add_column :notifications, :payload, :jsonb, default: {}, null: false
  end
end
