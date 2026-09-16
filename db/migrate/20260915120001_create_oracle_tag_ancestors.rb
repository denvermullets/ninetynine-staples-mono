class CreateOracleTagAncestors < ActiveRecord::Migration[8.1]
  def change
    # Closure table over the tag hierarchy. Every tag has a depth-0 row pointing at itself, so "cards
    # carrying this tag or anything under it" is one join with no recursion.
    create_table :oracle_tag_ancestors do |t|
      t.references :ancestor, null: false, foreign_key: { to_table: :oracle_tags }, index: true
      t.references :descendant, null: false, foreign_key: { to_table: :oracle_tags }, index: false
      t.integer :depth, null: false
    end

    add_index :oracle_tag_ancestors, %i[descendant_id ancestor_id], unique: true
  end
end
