# "Anything I own moves ±$5 / ±15% daily or weekly": a saved movers-table filter, run for its owner.
#
# One notification per rule however many cards matched, stating the count. The count comes from
# CollectionStats::MoversTable with the rule's own filters, the same query the movers page runs, so
# the number in the notification is the number the page it links to shows - less any card the user
# watches with a per-card override in the same window, which speaks for itself instead.
module PriceAlerts
  class EvaluateMovementRules < Evaluation
    KIND = 'price_movement'.freeze

    def call
      due(PriceAlert.active.movement_rules).includes(:user).find_each { |rule| evaluate(rule) }
    end

    private

    def evaluate(rule)
      count = matching_count(rule)
      return record(rule) if count.zero?

      record(rule, kind: KIND, payload: payload(rule, count))
    end

    def matching_count(rule)
      CollectionStats::MoversTable.for_owner(user: rule.user, filters: rule.movers_filters,
                                             collection_id: rule.collection_id, per_page: 1,
                                             exclude_card_ids: overridden_card_ids(rule)).call[:total]
    end

    def overridden_card_ids(rule)
      PriceAlert.active.card_overrides.where(user_id: rule.user_id, window: rule.window).pluck(:magic_card_id)
    end

    def payload(rule, count)
      { subject: "#{count} #{'card'.pluralize(count)} you own", count: count,
        summary: summary(rule), window: WINDOW_WORDS.fetch(rule.window) }
    end

    # "±$5.00", "+15%", or "-$5.00 and -15%" when the rule needs both
    def summary(rule)
      sign = SIGNS.fetch(rule.direction)
      parts = []
      parts << "#{sign}#{money(rule.min_delta_amount)}" if rule.min_delta_amount
      parts << "#{sign}#{percent(rule.min_delta_percent)}" if rule.min_delta_percent
      parts.join(' and ')
    end
  end
end
