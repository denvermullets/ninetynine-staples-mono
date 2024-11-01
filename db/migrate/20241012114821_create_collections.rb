class CreateCollections < ActiveRecord::Migration[7.2]
  def change
    create_table :collections do |t|
      t.string :name
      t.text :description
      t.string :type
      t.decimal :total_value, precision: 15, scale: 2, default: 0

      t.belongs_to :user, foreign_key: "user_id", null: false

      t.timestamps
    end
  end
end
