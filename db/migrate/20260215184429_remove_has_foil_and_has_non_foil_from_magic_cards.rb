class RemoveHasFoilAndHasNonFoilFromMagicCards < ActiveRecord::Migration[8.1]
  def change
    remove_column :magic_cards, :has_foil, :boolean
    remove_column :magic_cards, :has_non_foil, :boolean
  end
end
