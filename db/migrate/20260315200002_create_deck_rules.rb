class CreateDeckRules < ActiveRecord::Migration[8.0]
  def change
    create_table :deck_rules do |t|
      t.string :name, null: false
      t.text :description
      t.string :rule_type, null: false
      t.integer :value, null: false
      t.references :bracket, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :deck_rules, [:rule_type, :bracket_id], unique: true
  end
end
