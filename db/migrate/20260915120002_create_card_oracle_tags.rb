class CreateCardOracleTags < ActiveRecord::Migration[8.1]
  def change
    create_table :card_oracle_tags do |t|
      t.references :oracle_tag, null: false, foreign_key: true, index: false
      # uuid to match magic_cards.scryfall_oracle_id. card_roles uses a string here and every join
      # against it needs a cast on the magic_cards side; this table does not repeat that.
      t.uuid :scryfall_oracle_id, null: false
      t.string :weight
      t.text :annotation
      t.string :source, default: 'scryfall', null: false
      t.references :user, foreign_key: true
      t.timestamps
    end

    add_index :card_oracle_tags, %i[oracle_tag_id scryfall_oracle_id source],
              unique: true, name: 'idx_card_oracle_tags_unique'
    add_index :card_oracle_tags, :scryfall_oracle_id
  end
end
