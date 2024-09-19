class CreateRulings < ActiveRecord::Migration[7.2]
  def change
    create_table :rulings do |t|
      t.date :ruling_date
      t.string :ruling

      t.timestamps
    end
  end
end
