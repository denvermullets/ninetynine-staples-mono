# job will pull all collections that have a given card and update the total value
class UpdateCollections < ApplicationJob
  queue_as :collection_updates

  def perform(card, price_date = nil)
    price_change = fresh_changes(card.price_change.deep_symbolize_keys, price_date)
    return if price_change_is_zero?(price_change)

    CollectionMagicCard.where(magic_card_id: card.id)
                       .includes(:collection)
                       .in_batches(of: 1000) do |batch|
      collection_updates = {}

      batch.each do |collection_magic_card|
        collection = collection_magic_card.collection
        next unless collection

        collection_updates[collection.id] ||= 0
        collection_updates[collection.id] += calculate_price_change(collection_magic_card,
                                                                    price_change)
      end

      # update all collections
      collection_updates.each do |collection_id, total_price_change|
        Collection.where(id: collection_id).update_all(['total_value = total_value + ?',
                                                        total_price_change])
      end
    end
  end

  # only deltas produced by this run's price date count. a card whose history has
  # stalled still reports a change between its last two entries, and without this
  # that same change gets subtracted again on every single ingest
  def fresh_changes(price_change, price_date)
    return price_change if price_date.blank?

    price_change.select { |_type, data| data[:date] == price_date }
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
