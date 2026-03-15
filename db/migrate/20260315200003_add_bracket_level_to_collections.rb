class AddBracketLevelToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :bracket_level, :integer
    add_index :collections, :bracket_level
  end
end
