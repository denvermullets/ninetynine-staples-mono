class AddScryfallOracleIdToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :scryfall_oracle_id, :uuid
    add_index :magic_cards, :scryfall_oracle_id
  end
end
