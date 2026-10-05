# What the three price alert evaluators share: which alerts are still due for a price date, and how
# an evaluated alert is recorded.
#
# Idempotent by `last_evaluated_on`. An alert is stamped with the price date in the same transaction
# as its notification, so a retried or duplicated run skips everything it already got to and never
# notifies twice. Notifications::Deliver holds its broadcasts until that transaction commits.
#
# Written with update_columns rather than update!: the job only moves its own bookkeeping, and an
# alert that no longer validates (say, its collection changed hands) still has to be marked done.
module PriceAlerts
  class Evaluation < Service
    WINDOW_WORDS = { 'daily' => 'today', 'weekly' => 'this week' }.freeze
    SIGNS = { 'up' => '+', 'down' => '-', 'both' => '±' }.freeze

    def initialize(price_date)
      @price_date = price_date.to_date
    end

    private

    def due(scope)
      scope.where('price_alerts.last_evaluated_on IS NULL OR price_alerts.last_evaluated_on <> ?', @price_date)
    end

    # notifies when given a payload, then stamps the alert either way
    def record(alert, kind: nil, payload: nil, **attributes)
      PriceAlert.transaction do
        if payload
          Notifications::Deliver.call(user: alert.user, kind: kind, notifiable: alert, payload: payload)
          attributes[:last_fired_at] = Time.current
        end

        alert.update_columns(last_evaluated_on: @price_date, **attributes)
      end
    end

    def money(amount)
      ActiveSupport::NumberHelper.number_to_currency(amount)
    end

    def percent(amount)
      "#{ActiveSupport::NumberHelper.number_to_rounded(amount, precision: 1, strip_insignificant_zeros: true)}%"
    end

    # "+$5.20", "-$1.00"
    def signed_money(amount)
      "#{amount.negative? ? '-' : '+'}#{money(amount.abs)}"
    end

    def signed_percent(amount)
      "#{amount.negative? ? '-' : '+'}#{percent(amount.abs)}"
    end
  end
end
