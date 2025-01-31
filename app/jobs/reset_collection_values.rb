# job will reset all the collection values to $0
class ResetCollectionValues < ApplicationJob
  def perform
    Collection.all.each do |col|
      total_value = 0
      col.update(total_value:)

      cards = col.collection_magic_cards
      cards.each do |card|
        foil = card.magic_card.foil_price
        normal = card.magic_card.normal_price

        total_value += (foil * card.foil_quantity) + (normal * card.quantity)
      end

      col.update(total_value:)
    end
  end
end
