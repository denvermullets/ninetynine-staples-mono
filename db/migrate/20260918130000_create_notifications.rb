class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      # the (user_id, read_at) index below covers lookups by user on its own
      t.references :user, null: false, foreign_key: true, index: false
      # nullable: not every future notification will be about a record
      t.references :notifiable, polymorphic: true
      t.string :kind, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, %i[user_id read_at]
  end
end
