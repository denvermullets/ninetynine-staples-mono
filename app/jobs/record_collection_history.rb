# Records daily snapshot of collection values for historical tracking
class RecordCollectionHistory < ApplicationJob
  def perform
    puts 'Recording collection history snapshots'

    Collection.find_each do |collection|
      record_snapshot(collection)
    end

    puts 'Completed recording collection history snapshots'
  end

  private

  def record_snapshot(collection)
    today = Date.today.to_s
    current_value = collection.total_value.to_f

    # Initialize collection_history if nil
    history = collection.collection_history || {}

    # Skip if we already have an entry for today
    return if history[today].present?

    # Add today's value to the history
    history[today] = current_value

    collection.update_column(:collection_history, history)
  end
end
