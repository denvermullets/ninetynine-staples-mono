class CreateScryfallBulkImports < ActiveRecord::Migration[8.1]
  def change
    create_table :scryfall_bulk_imports do |t|
      t.string :bulk_type, null: false
      t.datetime :remote_updated_at
      t.datetime :imported_at
      t.integer :tag_count
      t.integer :tagging_count
      t.timestamps
    end

    add_index :scryfall_bulk_imports, :bulk_type, unique: true
  end
end
