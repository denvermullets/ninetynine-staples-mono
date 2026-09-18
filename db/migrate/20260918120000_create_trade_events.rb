class CreateTradeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :trade_events do |t|
      t.references :trade, null: false, foreign_key: true
      # nullable: `completed` is the trade closing on its own once both confirmations are in
      t.references :user, foreign_key: true
      t.string :event, null: false

      t.datetime :created_at, null: false
    end
  end
end
