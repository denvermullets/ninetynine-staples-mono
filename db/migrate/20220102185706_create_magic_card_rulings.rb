class CreateMagicCardRulings < ActiveRecord::Migration[7.2]
  def change
    create_table :magic_card_rulings do |t|
      t.belongs_to :magic_card
      t.belongs_to :ruling

      t.timestamps
    end
  end
end
