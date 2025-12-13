class AddValueHistoryToBoxsets < ActiveRecord::Migration[8.1]
  def change
    add_column :boxsets, :value_history, :jsonb, default: { normal: [], foil: [] }
  end
end
