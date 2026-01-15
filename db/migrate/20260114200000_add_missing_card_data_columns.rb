class AddMissingCardDataColumns < ActiveRecord::Migration[8.1]
  def change
    # Add columns to magic_cards
    add_column :magic_cards, :layout, :string
    add_column :magic_cards, :security_stamp, :string
    add_column :magic_cards, :can_be_commander, :boolean, default: false
    add_column :magic_cards, :can_be_brawl_commander, :boolean, default: false
    add_column :magic_cards, :can_be_oathbreaker_commander, :boolean, default: false

    # Create finishes lookup table
    create_table :finishes do |t|
      t.string :name
      t.timestamps
    end
    add_index :finishes, :name, unique: true

    # Create magic_card_finishes join table
    create_table :magic_card_finishes do |t|
      t.references :magic_card, null: false, foreign_key: true
      t.references :finish, null: false, foreign_key: true
      t.timestamps
    end
    add_index :magic_card_finishes, [:magic_card_id, :finish_id], unique: true

    # Create frame_effects lookup table
    create_table :frame_effects do |t|
      t.string :name
      t.timestamps
    end
    add_index :frame_effects, :name, unique: true

    # Create magic_card_frame_effects join table
    create_table :magic_card_frame_effects do |t|
      t.references :magic_card, null: false, foreign_key: true
      t.references :frame_effect, null: false, foreign_key: true
      t.timestamps
    end
    add_index :magic_card_frame_effects, [:magic_card_id, :frame_effect_id], unique: true

    # Create magic_card_variations self-referential join table
    create_table :magic_card_variations do |t|
      t.references :magic_card, null: false, foreign_key: true
      t.references :variation, null: false, foreign_key: { to_table: :magic_cards }
      t.timestamps
    end
    add_index :magic_card_variations, [:magic_card_id, :variation_id], unique: true
  end
end
