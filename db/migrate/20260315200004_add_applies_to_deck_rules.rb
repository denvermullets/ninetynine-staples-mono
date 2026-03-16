class AddAppliesToDeckRules < ActiveRecord::Migration[8.0]
  def change
    add_column :deck_rules, :applies_to, :string, null: false, default: 'all'

    change_column_null :deck_rules, :bracket_id, true

    remove_index :deck_rules, %i[rule_type bracket_id], unique: true
    add_index :deck_rules, %i[rule_type applies_to bracket_id],
              unique: true, name: 'index_deck_rules_on_type_applies_to_bracket'
  end
end
