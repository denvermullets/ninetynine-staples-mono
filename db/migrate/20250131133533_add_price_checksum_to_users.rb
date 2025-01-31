class AddPriceChecksumToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :prices_last_updated_at, :string
  end
end
