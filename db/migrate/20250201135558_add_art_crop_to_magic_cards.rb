class AddArtCropToMagicCards < ActiveRecord::Migration[8.0]
  def change
    add_column :magic_cards, :art_crop, :string
    add_column :magic_cards, :image_updated_at, :datetime
  end
end
