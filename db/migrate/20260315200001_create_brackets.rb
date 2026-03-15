class CreateBrackets < ActiveRecord::Migration[8.0]
  def change
    create_table :brackets do |t|
      t.integer :level, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end

    add_index :brackets, :level, unique: true
  end
end
