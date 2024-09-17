class CreatePrintings < ActiveRecord::Migration[7.2]
  def change
    create_table :printings do |t|
      t.belongs_to :magic_card
      t.string :boxset_code

      t.timestamps
    end
  end
end
