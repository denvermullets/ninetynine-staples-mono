# Formatting for the set detail page. The rows it renders are plain hashes out of
# CollectionStats::SetCards rather than MagicCard records, so the usual model predicates are not
# available and the few bits of presentation logic they would have carried live here.
module CollectionSetsHelper
  RARITY_CHIP = {
    'mythic' => 'bg-orange-900/30 text-orange-400 border-orange-500/30',
    'rare' => 'bg-amber-900/30 text-amber-400 border-amber-500/30',
    'uncommon' => 'bg-slate-700/40 text-slate-300 border-slate-400/30',
    'common' => 'bg-neutral-800/40 text-neutral-400 border-neutral-500/30'
  }.freeze

  # Copies, not printings - the row above already says 1/3 for printings, and what somebody wants to
  # know here is whether the two they have are the pair they were after. Foils are called out
  # because a foil is not a spare of the non-foil.
  def owned_marker(quantity, foil_quantity)
    parts = []
    parts << "x#{quantity}" if quantity.positive?
    parts << "x#{foil_quantity} foil" if foil_quantity.positive?

    parts.any? ? parts.join(' + ') : nil
  end

  def rarity_chip_class(rarity)
    RARITY_CHIP.fetch(rarity.to_s, 'bg-neutral-800/40 text-neutral-400 border-neutral-500/30')
  end

  # The sentence under the progress bar. Which one is right depends on whether the set had a numbered
  # run to measure against, and saying so is the difference between a reader trusting the bar and
  # wondering why their 26 Secret Lairs are 4%.
  def completion_basis_text(stats)
    return 'this set has no numbered run, so every printing counts toward the bar' if stats[:basis] == :all

    "the numbered run, #{number_with_delimiter(stats[:variant_owned])} of " \
      "#{number_with_delimiter(stats[:variant_total])} once variants are counted"
  end
end
