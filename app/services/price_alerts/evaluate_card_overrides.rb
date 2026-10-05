# One card's own movement rule, which takes it out of the user's collection-wide rules for that
# window.
#
# Measured on the unit price rather than a holding, since the card may be a want nobody owns. The
# change columns are percentages, so the dollar move is recovered the way CollectionStats::Sql.delta
# does it: delta = price * pct / (100 + pct). The percentage is the column itself. With finish `any`
# each finish is tried and the bigger qualifying move is reported.
module PriceAlerts
  class EvaluateCardOverrides < Evaluation
    KIND = 'price_movement'.freeze
    CHANGE_COLUMNS = {
      'daily' => { normal_price: :price_change_daily_normal, foil_price: :price_change_daily_foil },
      'weekly' => { normal_price: :price_change_weekly_normal, foil_price: :price_change_weekly_foil }
    }.freeze

    def call
      due(PriceAlert.active.card_overrides).includes(:user, :magic_card).find_each { |alert| evaluate(alert) }
    end

    private

    def evaluate(alert)
      move = qualifying_moves(alert).max_by { |candidate| candidate[:delta].abs }
      return record(alert) if move.nil?

      record(alert, kind: KIND, payload: payload(alert, move))
    end

    def qualifying_moves(alert)
      PriceAlert::PRICE_COLUMNS.fetch(alert.finish)
                               .filter_map { |column| move(alert, column) }
                               .select { |candidate| qualifies?(alert, candidate) }
    end

    # nil when the finish has no price or no change to measure
    def move(alert, price_column)
      price = alert.magic_card[price_column]
      pct = alert.magic_card[CHANGE_COLUMNS.fetch(alert.window).fetch(price_column)]
      return if price.nil? || !price.positive? || pct.nil? || pct == -100

      { price: price, percent: pct.to_d, delta: (price * pct / (100 + pct)).round(2) }
    end

    def qualifies?(alert, candidate)
      direction_matches?(alert.direction, candidate[:delta]) &&
        at_least?(candidate[:delta].abs, alert.min_delta_amount) &&
        at_least?(candidate[:percent].abs, alert.min_delta_percent) &&
        at_least?(candidate[:price], alert.min_price)
    end

    # a move that rounds to $0.00 is no move, the same rule the movers table drops it on
    def direction_matches?(direction, delta)
      case direction
      when 'up' then delta.positive?
      when 'down' then delta.negative?
      else !delta.zero?
      end
    end

    # an unset minimum filters nothing
    def at_least?(value, minimum)
      minimum.nil? || value >= minimum
    end

    def payload(alert, move)
      { subject: alert.magic_card.name, count: 1,
        summary: "#{signed_money(move[:delta])} (#{signed_percent(move[:percent])})",
        window: WINDOW_WORDS.fetch(alert.window) }
    end
  end
end
