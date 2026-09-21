# Wording for the deck comparison results: what a tab is called, and how sure its value is.
module DeckComparisonsHelper
  # a side that is one of the viewer's decks goes by its name; a paste has none, so it stays "A" / "B"
  def deck_compare_side_name(side)
    side[:deck_name].presence&.truncate(24) || side[:label]
  end

  def deck_compare_tab_label(tab, sides)
    case tab.to_s
    when 'only_a' then "Only in #{deck_compare_side_name(sides.first)}"
    when 'only_b' then "Only in #{deck_compare_side_name(sides.last)}"
    else 'Shared'
    end
  end

  # a pasted card is priced at a generic printing, so its total is a guess and says so: "~$412.00".
  # A shared card is drawn with a real deck's printing whenever either side is one.
  def deck_compare_value(tab, sides, value)
    priced_by = { 'only_a' => [sides.first], 'only_b' => [sides.last] }.fetch(tab.to_s, sides)
    approximate = priced_by.none? { |side| side[:source] == 'deck' }

    "#{'~' if approximate}#{number_to_currency(value)}"
  end

  def deck_compare_skipped_names(entries)
    entries.map { |entry| "#{entry[:quantity]} #{entry[:name]}" }.to_sentence
  end
end
