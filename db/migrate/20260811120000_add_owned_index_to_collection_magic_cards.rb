# Every panel on the analytics dashboard opens with the same CTE: filter collection_magic_cards on
# (collection_id, staged, needed), then group by magic_card_id. The table only had single-column
# indexes, so that used index_collection_magic_cards_on_collection_id and rechecked staged and
# needed on the heap - once per panel, and a dashboard load is up to four panels.
#
# magic_card_id rides along as an INCLUDE column rather than a fourth key column: nothing filters or
# orders by it, it is only ever the group-by, so it belongs in the leaf pages and not in the tree.
#
# Concurrently, because this is the app's hottest table and the collection pages read it on every
# request.
class AddOwnedIndexToCollectionMagicCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :collection_magic_cards, %i[collection_id staged needed],
              include: %i[magic_card_id],
              name: 'index_cmc_on_collection_staged_needed',
              algorithm: :concurrently
  end
end
