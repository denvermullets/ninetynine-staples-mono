class CreateLegalities < ActiveRecord::Migration[8.1]
  def change
    create_table :legalities do |t|
      t.string :name

      t.timestamps
    end
    add_index :legalities, :name, unique: true
  end
end
