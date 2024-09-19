class CreateKeywords < ActiveRecord::Migration[7.2]
  def change
    create_table :keywords do |t|
      t.string :keyword

      t.timestamps
    end
  end
end
