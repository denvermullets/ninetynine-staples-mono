class AddKeyruneCodeToBoxsets < ActiveRecord::Migration[7.2]
  def change
    add_column :boxsets, :keyrune_code, :string
  end
end
