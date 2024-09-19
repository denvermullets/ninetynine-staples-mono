class AddOtherFaceUuidToMagicCards < ActiveRecord::Migration[7.2]
  def change
    add_column :magic_cards, :other_face_uuid, :string
  end
end
