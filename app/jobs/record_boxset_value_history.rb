# Records daily snapshot of boxset values (total of all cards in set)
class RecordBoxsetValueHistory < ApplicationJob
  queue_as :background

  def perform
    puts 'Recording boxset value history snapshots'

    Boxset.find_each do |boxset|
      record_snapshot(boxset)
    end

    puts 'Completed recording boxset value history snapshots'
  end

  private

  def record_snapshot(boxset)
    today = Date.today.to_s

    # Initialize value_history if nil
    history = boxset.value_history || { normal: [], foil: [] }

    # Skip if we already have an entry for today
    return if entry_exists_for_today?(history, today)

    # Calculate total normal and foil values for all cards in this boxset
    normal_total = boxset.magic_cards.sum(:normal_price).to_f
    foil_total = boxset.magic_cards.sum(:foil_price).to_f

    # Add today's values to the history
    history['normal'] << { today => normal_total }
    history['foil'] << { today => foil_total }

    boxset.update_column(:value_history, history)
  end

  def entry_exists_for_today?(history, today)
    return false if history['normal'].nil? || history['foil'].nil?

    history['normal'].any? { |entry| entry.key?(today) } ||
      history['foil'].any? { |entry| entry.key?(today) }
  end
end
