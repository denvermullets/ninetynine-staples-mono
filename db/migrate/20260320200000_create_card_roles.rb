class CreateCardRoles < ActiveRecord::Migration[8.0]
  def change
    create_table :card_roles do |t|
      t.string :scryfall_oracle_id, null: false
      t.string :role, null: false
      t.string :effect, null: false
      t.float :confidence, null: false, default: 1.0
      t.string :source, null: false, default: 'pattern'
      t.timestamps
    end

    add_index :card_roles, :scryfall_oracle_id
    add_index :card_roles, [:scryfall_oracle_id, :role, :effect], unique: true, name: 'idx_card_roles_unique'
    add_index :card_roles, :role
    add_index :card_roles, [:role, :effect]
  end
end
