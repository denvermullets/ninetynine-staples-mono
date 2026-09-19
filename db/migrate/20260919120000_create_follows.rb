class CreateFollows < ActiveRecord::Migration[8.1]
  def change
    create_table :follows do |t|
      # the unique (follower_id, followed_id) index below covers lookups by follower on its own
      t.references :follower, null: false, foreign_key: { to_table: :users }, index: false
      t.references :followed, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :follows, %i[follower_id followed_id], unique: true
  end
end
