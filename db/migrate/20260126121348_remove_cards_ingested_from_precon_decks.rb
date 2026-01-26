class RemoveCardsIngestedFromPreconDecks < ActiveRecord::Migration[8.1]
  def change
    remove_column :precon_decks, :cards_ingested, :boolean, default: false
  end
end
