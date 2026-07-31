# job will reset all the collection values to $0
class ResetCollectionValues < ApplicationJob
  queue_as :collection_updates

  def perform
    Collection.find_each do |col|
      cards = col.collection_magic_cards

      foil_quantity = cards.sum(&:foil_quantity)
      quantity = cards.sum(&:quantity)
      # prices are nullable - to_d treats nil as 0 and keeps the math in BigDecimal
      total_value = cards.sum do |card|
        (card.magic_card.foil_price.to_d * card.foil_quantity) +
          (card.magic_card.normal_price.to_d * card.quantity)
      end

      col.update(total_value: total_value, total_foil_quantity: foil_quantity, total_quantity: quantity)
    end
  end
end
