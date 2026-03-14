class CreateMagicCardIdentifiers < ActiveRecord::Migration[8.0]
  def change
    create_table :magic_card_identifiers do |t|
      t.references :magic_card, null: false, foreign_key: true, index: { unique: true }

      t.string :abu_id
      t.string :card_kingdom_etched_id
      t.string :card_kingdom_foil_id
      t.string :card_kingdom_id
      t.string :cardsphere_foil_id
      t.string :cardsphere_id
      t.string :cardtrader_id
      t.string :csi_id
      t.string :mcm_id
      t.string :mcm_meta_id
      t.string :miniaturemarket_id
      t.string :mtg_arena_id
      t.string :mtgjson_foil_version_id
      t.string :mtgjson_non_foil_version_id
      t.string :mtgjson_v4_id
      t.string :mtgo_foil_id
      t.string :mtgo_id
      t.string :multiverse_id
      t.string :scg_id
      t.string :scryfall_card_back_id
      t.string :scryfall_id
      t.string :scryfall_illustration_id
      t.string :scryfall_oracle_id
      t.string :tcgplayer_alternative_foil_product_id
      t.string :tcgplayer_etched_product_id
      t.string :tcgplayer_product_id
      t.string :tnt_id

      t.timestamps
    end

    add_index :magic_card_identifiers, :scryfall_id
    add_index :magic_card_identifiers, :multiverse_id
  end
end
