# Pasted decklists are resolved case-insensitively: lower(name) IN (...) and then
# lower(face_name) IN (...) (WantList::BulkImport#resolve). The plain btree on name is
# case-sensitive and face_name has no index at all, so both lookups seq-scan 107k rows.
#
# The want importer gets away with it because it runs in a job. Deck comparison resolves two
# lists inside a public request, on every grouping / sort change, so it needs expression
# indexes. Arel's arel_table[:name].lower emits LOWER("magic_cards"."name"), which matches.
#
# index_magic_cards_on_name stays: the exact-match searches still use it.
#
# Concurrently, because magic_cards is read on nearly every request.
class AddLowerNameIndexesToMagicCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :magic_cards, 'lower(name)', name: 'index_magic_cards_on_lower_name', algorithm: :concurrently
    add_index :magic_cards, 'lower(face_name)', name: 'index_magic_cards_on_lower_face_name',
                                                 algorithm: :concurrently
  end
end
