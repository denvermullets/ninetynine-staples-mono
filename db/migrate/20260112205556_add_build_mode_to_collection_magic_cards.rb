class AddBuildModeToCollectionMagicCards < ActiveRecord::Migration[8.1]
  def change
    # Staged = in build mode (not finalized)
    add_column :collection_magic_cards, :staged, :boolean, default: false, null: false

    # Source collection (null = temp/planned card)
    add_column :collection_magic_cards, :source_collection_id, :bigint, null: true

    # Staged quantities (before finalize)
    add_column :collection_magic_cards, :staged_quantity, :integer, default: 0, null: false
    add_column :collection_magic_cards, :staged_foil_quantity, :integer, default: 0, null: false

    # Needed = finalized but user doesn't own (was temp)
    add_column :collection_magic_cards, :needed, :boolean, default: false, null: false

    add_index :collection_magic_cards, :staged
    add_index :collection_magic_cards, :needed
    add_index :collection_magic_cards, :source_collection_id
    add_foreign_key :collection_magic_cards, :collections, column: :source_collection_id
  end
end
