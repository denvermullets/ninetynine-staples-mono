# "Tell me when this card goes above / below $X", checked against one day's prices.
#
# Fires on the crossing, not on being past the line: `last_side` remembers which side the price was
# on, and the alert fires only when the price lands on its direction's side from the other one. An
# alert sitting above $X stays quiet day after day; a drop under and a climb back fires it again.
# An alert with no `last_side` yet (its card had no price when it was made) only learns it.
#
# Once on its direction's side, the alert stays there until the price comes back past the line by
# PriceAlert::REARM_MARGIN: an "above $20" alert re-arms under $19, not at $19.99, so a card
# bouncing around $20 notifies once rather than every other day.
#
# No price, or a price of 0, is no data rather than a crossing, so the side is left alone.
#
# Every printing is preloaded and every oracle id priced in one grouped query, so there is no
# per-alert price lookup however many alerts are due.
module PriceAlerts
  class EvaluateThresholds < Evaluation
    KIND = 'price_threshold_crossed'.freeze

    def call
      due(PriceAlert.active.thresholds).includes(:user, :magic_card).find_in_batches do |alerts|
        cheapest = PriceAlert.cheapest_printings(alerts.filter_map(&:scryfall_oracle_id).uniq)
        alerts.each { |alert| evaluate(alert, cheapest) }
      end
    end

    private

    def evaluate(alert, cheapest)
      price = alert.current_price(cheapest: cheapest)
      side = alert.side_for(price)
      return record(alert) if side.nil? || held?(alert, side, price)
      return record(alert, last_side: side) unless crossed?(alert, side)

      record(alert, kind: KIND, payload: payload(alert, price, cheapest), last_side: side)
    end

    # a disarmed alert whose price has slipped back over the line but not yet past the margin
    def held?(alert, side, price)
      alert.disarmed? && side != alert.direction && !alert.rearms_at?(price)
    end

    def crossed?(alert, side)
      alert.last_side.present? && side != alert.last_side && side == alert.direction
    end

    def payload(alert, price, cheapest)
      { card: card_name(alert, cheapest), direction: alert.direction,
        threshold: money(alert.threshold_price), price: money(price) }
    end

    def card_name(alert, cheapest)
      alert.magic_card&.name || cheapest.dig(alert.scryfall_oracle_id, :name) || 'A card'
    end
  end
end
