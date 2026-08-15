# The explanatory line under the brew filters, and the small bits of wording the commander cards
# need. Here rather than in the partials because the strings are the part worth reading, and an ERB
# case statement buried in a class attribute is not.
module BrewHelper
  def brew_sort_text(sort)
    case sort
    when 'hipster'
      'Commanders your collection already supports, weighted towards the ones nobody plays. ' \
      'The interesting list - obscurity peaks in the middle of the rank range, so this is not ' \
      'the bulk rare nobody runs for a reason.'
    when 'rank'
      'Straight EDHREC order, most played first. Useful as a sanity check on the other sorts.'
    when 'mana_value'
      'Cheapest commanders first.'
    else
      'Commanders your collection supports best. Fit leads - your cards have to do what the ' \
      'commander wants - and how much of the 99 you could fill scales it.'
    end
  end

  def brew_band_text(band)
    case band
    when 'staples' then 'The commanders everybody knows.'
    when 'known' then 'Played, but not the default answer - where the good brews live.'
    when 'obscure' then 'Rank 8,000 and beyond. Some of this is unplayed for a reason.'
    else ''
    end
  end

  # "68 of 99 already in your binders". The 99 is the format's number and stays fixed - it is the
  # thing being measured against, and scaling it to whatever the collection can reach would make the
  # sentence agree with itself no matter what it said.
  def brew_pool_sentence(row)
    "#{number_with_delimiter(row[:owned_pool])} cards in your collection could go in this deck"
  end

  def brew_bottleneck_label(role)
    return 'nothing missing' if role.blank?

    "short on #{role.tr('_', ' ')}"
  end

  # The completeness bar reads as a percentage, but the number behind it is a ratio of filled slots
  # to the 38 spell slots DeckTargets asks for - manabase is excluded, see Commanders::Buildability.
  def brew_completeness_percent(completeness)
    (completeness * 100).round
  end
end
