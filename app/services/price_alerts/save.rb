# Creates one of a user's price alerts, or updates one they already have, from request params.
#
# Only the fields the alert's kind takes are kept; anything else in the params is dropped. What an
# alert watches - its card or oracle id - is only accepted on create, so an alert never moves to
# another card. `active` is only accepted on update: a new alert always starts active.
#
# The caller is responsible for `alert` being the user's own (PriceAlertsController finds it through
# current_user.price_alerts); a movement rule's collection is checked by the model.
module PriceAlerts
  class Save < Service
    THRESHOLD_FIELDS = %i[finish direction threshold_price].freeze
    MOVEMENT_FIELDS = %i[collection_id finish direction window min_delta_amount min_delta_percent min_price].freeze
    TARGET_FIELDS = { 'threshold' => %i[magic_card_id scryfall_oracle_id], 'movement' => %i[magic_card_id] }.freeze

    def initialize(user:, params:, alert: nil)
      @user = user
      @params = params
      @alert = alert
    end

    def call
      alert = @alert || @user.price_alerts.new(kind: @params[:kind].to_s)
      alert.assign_attributes(permitted(alert))

      { success: alert.save, alert: alert }
    end

    private

    def permitted(alert)
      fields = alert.threshold? ? THRESHOLD_FIELDS : MOVEMENT_FIELDS
      extra = alert.new_record? ? TARGET_FIELDS.fetch(alert.kind, []) : [:active]

      @params.permit(*fields, *extra)
    end
  end
end
