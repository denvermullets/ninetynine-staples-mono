class CreateMagicCardLegalities < ActiveRecord::Migration[8.1]
  def change
    create_table :magic_card_legalities do |t|
      t.references :magic_card, null: false, foreign_key: true
      t.references :legality, null: false, foreign_key: true
      t.string :status, null: false

      t.timestamps
    end

    add_index :magic_card_legalities, %i[magic_card_id legality_id], unique: true
    add_index :magic_card_legalities, :status
  end
end
