# Removes boxset value history data prior to the boxset's release date
# This cleans up any historical data that predates when the boxset was actually released
class TrimBoxsetValueHistory < ApplicationJob
  queue_as :background

  def perform
    puts 'Starting boxset value history trim'

    Boxset.find_each do |boxset|
      trim_boxset_history(boxset)
    end

    puts 'Completed boxset value history trim'
  end

  private

  def trim_boxset_history(boxset)
    return unless boxset.release_date.present?
    return unless boxset.value_history.present?

    puts "Processing boxset: #{boxset.name} (release date: #{boxset.release_date})"

    release_date = boxset.release_date.to_s
    trimmed_history = build_trimmed_history(boxset.value_history, release_date)

    update_and_log(boxset, trimmed_history, release_date)
  end

  def build_trimmed_history(value_history, release_date)
    {
      'normal' => trim_price_type(value_history['normal'], release_date),
      'foil' => trim_price_type(value_history['foil'], release_date)
    }
  end

  def update_and_log(boxset, trimmed_history, release_date)
    removed_count = count_entries(boxset.value_history) - count_entries(trimmed_history)

    if removed_count.positive?
      boxset.update_column(:value_history, trimmed_history)
      puts "  - Removed #{removed_count} entries before #{release_date} for #{boxset.name}"
    else
      puts "  - No entries to remove for #{boxset.name}"
    end
  end

  def trim_price_type(price_history, release_date)
    return [] unless price_history.present?

    price_history.select do |entry|
      date = entry.keys.first
      date >= release_date
    end
  end

  def count_entries(value_history)
    return 0 unless value_history.present?

    (value_history['normal']&.size || 0) + (value_history['foil']&.size || 0)
  end
end
