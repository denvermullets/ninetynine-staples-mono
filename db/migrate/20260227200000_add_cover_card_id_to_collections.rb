class AddCoverCardIdToCollections < ActiveRecord::Migration[8.0]
  def change
    add_reference :collections, :cover_card, null: true, foreign_key: { to_table: :magic_cards }
  end
end
