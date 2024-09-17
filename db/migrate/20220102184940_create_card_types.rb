class CreateCardTypes < ActiveRecord::Migration[7.2]
  def change
    create_table :card_types do |t|
      t.string :name

      t.timestamps
    end
  end
end
