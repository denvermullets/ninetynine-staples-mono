# Starting loyalty for planeswalkers and defense for battles. Strings like power and toughness, because
# mtgjson sends values such as "X".
#
# Existing rows fill in on the next IngestSetCards run for their set - CardCreator updates cards it
# already has, and the weekly IngestSets run covers every set.
class AddLoyaltyAndDefenseToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :loyalty, :string
    add_column :magic_cards, :defense, :string
  end
end
