module WantListHelper
  FOIL_PREFERENCE_LABELS = { 'any' => 'Foil or non-foil', 'foil' => 'Foil only', 'non_foil' => 'Non-foil only' }.freeze

  def want_foil_preference_options
    WantListItem::FOIL_PREFERENCES.map { |preference| [FOIL_PREFERENCE_LABELS.fetch(preference), preference] }
  end

  SHORT_FOIL_PREFERENCE_LABELS = { 'any' => 'Any finish', 'foil' => 'Foil', 'non_foil' => 'Non-foil' }.freeze

  # The price of the finish the want asks for, the way WantList::List sorts it. An any-finish want on
  # a card sold in both shows both, because either would do.
  def want_unit_price(item)
    card = item.magic_card
    normal = card.normal_price.to_d
    foil = card.foil_price.to_d

    parts = []
    parts << number_to_currency(normal) if item.foil_preference != 'foil' && normal.positive?
    parts << "#{number_to_currency(foil)} foil" if item.foil_preference != 'non_foil' && foil.positive?
    parts.any? ? parts.join(' / ') : '-'
  end

  def want_filter_text(filter)
    case filter
    when 'any_printing' then 'Wants any printing of the card would fill.'
    when 'specific' then 'Wants for one exact printing.'
    when 'owned' then 'Wants already covered by a copy in the collection - probably ready to come off the list.'
    else 'Every card on the list.'
    end
  end

  # Same answer as MagicCard#want_list_item_for, but from one load of the viewer's wants per request.
  # The mobile cards render eagerly for a whole page of cards, where a query per card adds up.
  def preloaded_want_item_for(card)
    return nil unless current_user

    @preloaded_want_items ||= current_user.want_list_items.to_a
    items = @preloaded_want_items.select { |item| item.satisfied_by?(card) }
    items.find { |item| item.magic_card_id == card.id } || items.first
  end
end
