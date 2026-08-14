# Formatting for the proxy page. Its rows are plain hashes out of CollectionStats::ProxyCards
# rather than CollectionMagicCard records, so the model predicates are not available and the
# presentation logic they would have carried lives here - the same reason CollectionSetsHelper
# exists, whose #owned_marker this page reuses for every quantity cell.
module CollectionProxiesHelper
  # The whole point of the row, in one chip.
  #
  # Three states, not two, because "you own this for real" and "you own this exact printing for real"
  # are different findings and only the second one means the proxy in your sleeve is redundant. A
  # card you proxied in Alpha and own in Revised is a proxy you MIGHT be able to retire - amber, go
  # and look - which is not the same as one whose real twin is already filed under the same number.
  #
  # same_printing wins when a card is both. It is the stronger answer, and the expansion lists every
  # location anyway for the reader who wants the other one.
  def proxy_status_chip(row)
    if row[:real_same_printing]
      { label: 'real copy owned', class: 'bg-accent-50/20 text-accent-50 border-accent-50/30' }
    elsif row[:real_other_printing]
      { label: 'real, other printing', class: 'bg-amber-900/30 text-amber-400 border-amber-500/30' }
    else
      { label: 'proxy only', class: 'bg-black/40 text-grey-text/50 border-highlight' }
    end
  end

  # The sentence under the toggle. Which list you are looking at is not obvious from the rows
  # themselves - "real owned" and "other printing" deliberately overlap - so it gets said.
  def proxy_filter_text(filter)
    case filter
    when 'proxy_only'
      'Proxies with no real copy anywhere in your collections - the shopping list.'
    when 'other_printing'
      'You own the real card, but in a different printing - proxies you may be able to retire ' \
      'by digging the version you already have out of a binder.'
    else
      'Every printing you hold a proxy of, one row each. Real copies are looked for across all ' \
      'your collections, not just the one selected above.'
    end
  end

  # The second half of that sentence. Only says anything when the axis is doing something - "and all
  # of them" after every other filter description is noise.
  #
  # The overlap gets called out rather than left to be discovered, because a reader who adds the
  # counts up and gets more than the total is entitled to know why.
  def proxy_location_text(location)
    case location
    when 'decks'
      'Only proxies sleeved in a deck.'
    when 'binders'
      'Only proxies sitting outside a deck. A printing proxied in both is in both lists.'
    when 'swappable'
      'Deck proxies whose real copy is sitting outside every deck - swaps you can make right now ' \
      'without taking another deck apart.'
    else
      ''
    end
  end

  # "Cube, Legacy Deck" - the collapsed row says WHERE without making somebody expand it. Truncated
  # rather than wrapped, because the count is the useful part once there are more than a few and the
  # expansion has the full list with quantities.
  def location_names(locations, limit: 3)
    names = locations.map { |location| location[:collection_name] }.compact
    return names.join(', ') if names.size <= limit

    "#{names.first(limit).join(', ')} +#{names.size - limit} more"
  end

  # A TILE IS A PRINTING, and the binders holding it are the caption underneath.
  #
  # The locations underneath a row are (collection x printing) pairs, which is the right grain for a
  # list and the wrong one for a strip of art: on the proxy side every location is the SAME printing,
  # because a row IS a printing, so one tile per location renders identical art once per binder. On
  # the real side the printings genuinely differ, and that difference is the whole reason to look at
  # the pictures - so both sides group to the printing and the collections become the caption.
  def group_locations_by_printing(locations)
    locations.group_by { |location| location[:printing_id] || location[:id] }
             .map { |_, group| printing_group(group) }
  end

  # A printing needs its set and number to be identifiable - "Underground Sea" names four different
  # cards to go and find, "3ED #286" names one.
  def printing_label(location, labels = {})
    variant = labels[location[:printing_id] || location[:id]]

    [["#{location[:set_code]} ##{location[:number]}"], variant].compact.flatten.join(' · ')
  end

  # Copies are summed across the binders so the badge on the art can say how many of this printing
  # you have in total, while the caption keeps the breakdown that says where.
  def printing_group(locations)
    locations.first.merge(
      locations: locations.sort_by { |location| location[:collection_name].to_s.downcase },
      qty: locations.sum { |location| location[:qty] },
      foil_qty: locations.sum { |location| location[:foil_qty] }
    )
  end
end
