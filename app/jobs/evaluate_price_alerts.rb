# Checks every active price alert against one day's prices and notifies whoever's alert went off.
#
# Enqueued by IngestPrices once a day's prices have landed. It reads prices off magic_cards and
# quantities off collection_magic_cards, so it does not wait for the per-card UpdateCollections jobs.
# Each evaluator stamps an alert with the price date as it goes, so a retry picks up where it left
# off and never notifies twice. Overrides go before the rules only so a card's own move is told first.
class EvaluatePriceAlerts < ApplicationJob
  queue_as :background

  def perform(price_date)
    PriceAlerts::EvaluateThresholds.call(price_date)
    PriceAlerts::EvaluateCardOverrides.call(price_date)
    PriceAlerts::EvaluateMovementRules.call(price_date)
    PriceAlerts::EvaluateBands.call(price_date)
  end
end
