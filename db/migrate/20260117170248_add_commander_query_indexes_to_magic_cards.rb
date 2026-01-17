class AddCommanderQueryIndexesToMagicCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :magic_cards, :can_be_commander, algorithm: :concurrently
    add_index :magic_cards, :edhrec_rank, algorithm: :concurrently
    add_index :magic_cards, :card_side, algorithm: :concurrently
    add_index :magic_cards, :rarity, algorithm: :concurrently
    add_index :magic_cards, [:can_be_commander, :boxset_id], algorithm: :concurrently
  end
end
