class CreateOracleTags < ActiveRecord::Migration[8.1]
  def change
    create_table :oracle_tags do |t|
      # Scryfall's stable tag id. Slugs can be renamed upstream, so this is the ingest key. Null for
      # user-created tags (STA-284).
      t.uuid :scryfall_id
      t.string :slug, null: false
      t.string :label, null: false
      t.text :description
      t.string :aliases, array: true, default: [], null: false
      t.string :source, default: 'scryfall', null: false
      # Scryfall asks downstream apps to be able to hide an individual community tag.
      t.boolean :disabled, default: false, null: false
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :oracle_tags, :scryfall_id, unique: true
    add_index :oracle_tags, :slug, unique: true
  end
end
