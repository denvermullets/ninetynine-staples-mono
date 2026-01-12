class AddBoardTypeToCollectionMagicCards < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_magic_cards, :board_type, :string, default: 'mainboard'
    add_index :collection_magic_cards, :board_type
  end
end
