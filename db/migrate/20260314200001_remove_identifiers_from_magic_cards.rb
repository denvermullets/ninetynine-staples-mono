class RemoveIdentifiersFromMagicCards < ActiveRecord::Migration[8.0]
  def change
    remove_column :magic_cards, :identifiers, :jsonb
  end
end
