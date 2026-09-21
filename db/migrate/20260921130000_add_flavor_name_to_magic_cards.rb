# The name printed on a card is not always its real one: Universes Beyond and Secret Lair printings
# carry an alternate ("Balin's Tomb" on an Ancient Tomb, "Cybertron" on a Command Tower), and deck
# sites export whichever printing the user picked. With only name and face_name stored, those lines
# never resolve and card search cannot find them either.
#
# Indexed on lower() for the same reason as name and face_name: Decklist::Resolve looks pasted lists
# up with lower(flavor_name) IN (...) inside a public request.
#
# Existing rows fill in on the next IngestSetCards run for their set.
class AddFlavorNameToMagicCards < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :magic_cards, :flavor_name, :string
    add_index :magic_cards, 'lower(flavor_name)', name: 'index_magic_cards_on_lower_flavor_name',
                                                   algorithm: :concurrently
  end
end
