# job will reset all the collection values to $0
class ResetCollectionValues < ApplicationJob
  queue_as :background

  def perform
    Collection.find_each do |col|
      cards = col.collection_magic_cards

      foil_quantity = cards.sum(&:foil_quantity)
      quantity = cards.sum(&:quantity)
      total_value = cards.sum do |card|
        (card.magic_card.foil_price * card.foil_quantity) +
          (card.magic_card.normal_price * card.quantity)
      end

      col.update(total_value: total_value, total_foil_quantity: foil_quantity, total_quantity: quantity)
    end
  end
end
