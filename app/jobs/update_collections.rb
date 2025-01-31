# job will pull all collections that have a given card and update the total value
class UpdateCollections < ApplicationJob
  def perform(card)
    price_change = card.price_change.deep_symbolize_keys
    return if price_change_is_zero?(price_change)

    CollectionMagicCard.where(magic_card_id: card.id)
                       .includes(:collection)
                       .in_batches(of: 1000) do |batch|
      collection_updates = {}

      batch.each do |collection_magic_card|
        collection = collection_magic_card.collection
        next unless collection

        collection_updates[collection.id] ||= 0
        collection_updates[collection.id] += calculate_price_change(collection_magic_card, price_change)
      end

      # update all collections
      collection_updates.each do |collection_id, total_price_change|
        Collection.where(id: collection_id).update_all("total_value = total_value + #{total_price_change}")
      end
    end
  end

  def price_change_is_zero?(price_change)
    price_change.dig(:foil, :change).to_d.zero? && price_change.dig(:normal, :change).to_d.zero?
  end

  def calculate_price_change(collection_magic_card, price_change)
    foil_quantity = collection_magic_card.foil_quantity || 0
    normal_quantity = collection_magic_card.quantity || 0

    (foil_quantity * price_change.dig(:foil, :change).to_d) +
      (normal_quantity * price_change.dig(:normal, :change).to_d)
  end
end
