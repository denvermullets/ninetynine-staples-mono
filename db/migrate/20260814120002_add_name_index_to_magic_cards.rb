# magic_cards has no index on name, despite name being the lookup key for most card searches in
# the app - every one of them does a seq scan over 107k rows today.
#
# A plain btree only serves the exact-match lookups (CardScanner::Search#find_exact_by_name,
# DeckBuilder::Search#newest_card_for_name, Collections::CardSearch). The unanchored
# ILIKE '%term%' searches still cannot use it and would need pg_trgm; that is a separate change,
# and .notes/0.md tracks it.
#
# Concurrently, because magic_cards is read on nearly every request.
class AddNameIndexToMagicCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :magic_cards, :name, algorithm: :concurrently
  end
end
