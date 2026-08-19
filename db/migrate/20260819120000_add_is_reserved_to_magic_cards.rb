class AddIsReservedToMagicCards < ActiveRecord::Migration[8.1]
  def change
    add_column :magic_cards, :is_reserved, :boolean, default: false, null: false
  end
end
