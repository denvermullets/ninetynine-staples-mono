# Wording for price alerts, and the bells that make them. See PriceAlert for the three shapes an alert
# takes.
module PriceAlertsHelper
  FINISH_LABELS = { 'normal' => 'non-foil', 'foil' => 'foil', 'any' => 'any finish' }.freeze
  WINDOW_LABELS = { 'daily' => 'Daily', 'weekly' => 'Weekly' }.freeze
  MOVEMENT_SIGNS = { 'up' => '+', 'down' => '-', 'both' => '±' }.freeze
  MOVEMENT_DIRECTIONS = { 'up' => 'up', 'down' => 'down', 'both' => 'up or down' }.freeze

  # What a bell answers to, so every bell for the same card - the table's and the mobile list's - can
  # be found and relit together after a write. A want for any printing watches the card's oracle id; a
  # bell on a single printing watches that printing.
  def price_alert_bell_key(magic_card_id: nil, scryfall_oracle_id: nil)
    magic_card_id ? "card-#{magic_card_id}" : "oracle-#{scryfall_oracle_id}"
  end

  # Whether an active threshold alert watches the bell's card. One query per request however many
  # bells the page draws.
  def price_alert_watched?(key)
    @price_alert_watched_keys ||= current_user.price_alerts.active.thresholds
                                              .pluck(:magic_card_id, :scryfall_oracle_id)
                                              .to_set do |card_id, oracle_id|
      price_alert_bell_key(magic_card_id: card_id, scryfall_oracle_id: oracle_id)
    end
    @price_alert_watched_keys.include?(key)
  end

  # The rule in plain English: "Above $20.00 (foil)", "Weekly, ±$5 and ±15%, up or down".
  def price_alert_condition(alert)
    alert.threshold? ? threshold_condition(alert) : movement_condition(alert)
  end

  # What the alert watches: a printing, any printing of a card, or a collection - all of them when none.
  # `cheapest` is PriceAlert.cheapest_printings, which names an oracle alert's card.
  def price_alert_subject(alert, cheapest: {})
    if alert.magic_card
      front_name(alert.magic_card.name)
    elsif alert.scryfall_oracle_id.present?
      front_name(cheapest.dig(alert.scryfall_oracle_id, :name)) || 'Unknown card'
    else
      alert.collection&.name || 'All collections'
    end
  end

  def price_alert_subtext(alert)
    if alert.magic_card
      "#{alert.magic_card.boxset&.name || 'Unknown set'} ##{alert.magic_card.card_number}"
    elsif alert.scryfall_oracle_id.present?
      'Any printing'
    end
  end

  def price_alert_last_fired(alert)
    alert.last_fired_at ? "#{time_ago_in_words(alert.last_fired_at)} ago" : 'Never'
  end

  # an amount as a form field shows it: "20.00", never BigDecimal's "0.2e2"
  def price_alert_amount(value)
    number_with_precision(value, precision: 2) if value
  end

  def price_alert_finish_options(alert)
    finishes = alert.threshold? && alert.magic_card_id ? PriceAlert::PRINTING_FINISHES : PriceAlert::FINISHES
    finishes.map { |finish| [FINISH_LABELS.fetch(finish).capitalize, finish] }
  end

  private

  def threshold_condition(alert)
    "#{alert.direction.capitalize} #{number_to_currency(alert.threshold_price)} " \
      "(#{FINISH_LABELS.fetch(alert.finish)})"
  end

  # The $ and % minimums both have to be cleared when both are set - see PriceAlerts::EvaluateCardOverrides
  # and CollectionStats::MoversTable - so they join with "and".
  def movement_condition(alert)
    extras = [(FINISH_LABELS.fetch(alert.finish) unless alert.finish == 'any'),
              ("cards #{number_to_currency(alert.min_price)}+" if alert.min_price)].compact

    ["#{WINDOW_LABELS.fetch(alert.window)}, #{minimum_moves(alert)}, #{MOVEMENT_DIRECTIONS.fetch(alert.direction)}",
     *extras].join(', ')
  end

  def minimum_moves(alert)
    sign = MOVEMENT_SIGNS.fetch(alert.direction)

    [("#{sign}#{price_alert_money(alert.min_delta_amount)}" if alert.min_delta_amount),
     ("#{sign}#{price_alert_number(alert.min_delta_percent)}%" if alert.min_delta_percent)].compact.join(' and ')
  end

  # the front face of a double-faced card's "Front // Back"
  def front_name(name)
    name&.split('//')&.first
  end

  # whole dollars without cents, so a rule reads "±$5" rather than "±$5.00"
  def price_alert_money(value)
    number_to_currency(value, precision: value == value.round ? 0 : 2)
  end

  def price_alert_number(value)
    number_with_precision(value, precision: 2, strip_insignificant_zeros: true)
  end
end
