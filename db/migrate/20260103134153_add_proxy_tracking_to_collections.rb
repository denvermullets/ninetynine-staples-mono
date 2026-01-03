class AddProxyTrackingToCollections < ActiveRecord::Migration[8.1]
  def change
    # Add proxy quantities to collection_magic_cards
    add_column :collection_magic_cards, :proxy_quantity, :integer, default: 0, null: false
    add_column :collection_magic_cards, :proxy_foil_quantity, :integer, default: 0, null: false

    # Add proxy aggregates to collections
    add_column :collections, :total_proxy_quantity, :integer, default: 0, null: false
    add_column :collections, :total_proxy_foil_quantity, :integer, default: 0, null: false
    add_column :collections, :proxy_total_value, :decimal, precision: 15, scale: 2, default: 0.0, null: false
  end
end
