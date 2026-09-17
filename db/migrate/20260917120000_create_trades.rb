class CreateTrades < ActiveRecord::Migration[8.1]
  def change
    create_table :trades do |t|
      t.references :proposer, null: false, foreign_key: { to_table: :users }
      t.references :recipient, null: false, foreign_key: { to_table: :users }
      t.references :parent_trade, foreign_key: { to_table: :trades }
      t.string :status, null: false, default: 'proposed'
      t.text :message
      t.datetime :proposer_completed_at
      t.datetime :recipient_completed_at

      t.timestamps
    end

    add_index :trades, %i[recipient_id status]
    add_index :trades, %i[proposer_id status]
  end
end
