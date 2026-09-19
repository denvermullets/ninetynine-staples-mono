class CreateWantListItems < ActiveRecord::Migration[8.1]
  def change
    create_table :want_list_items do |t|
      # the unique (user_id, magic_card_id) index below covers lookups by user on its own
      t.references :user, null: false, foreign_key: true, index: false
      t.references :magic_card, null: false, foreign_key: true
      # copied from the card on create so matching never has to join magic_cards; uuid to match
      # magic_cards.scryfall_oracle_id. nullable because some printings arrive without one.
      t.uuid :scryfall_oracle_id
      t.boolean :any_printing, null: false, default: true
      t.integer :quantity, null: false, default: 1
      t.string :foil_preference, null: false, default: 'any'
      t.text :notes

      t.timestamps
    end

    add_index :want_list_items, %i[user_id magic_card_id], unique: true
    # one "any printing" row per card per user; specific printings of the same card sit alongside it
    add_index :want_list_items, %i[user_id scryfall_oracle_id],
              unique: true, where: 'any_printing', name: 'index_want_list_items_on_user_and_oracle_any_printing'
    add_index :want_list_items, :scryfall_oracle_id
  end
end
