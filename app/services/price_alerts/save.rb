# Creates one of a user's price alerts, or updates one they already have, from request params.
#
# Only the fields the alert's kind takes are kept; anything else in the params is dropped. What an
# alert watches - its card or oracle id - is only accepted on create, so an alert never moves to
# another card. `active` is only accepted on update: a new alert always starts active.
#
# The caller is responsible for `alert` being the user's own (PriceAlertsController finds it through
# current_user.price_alerts); a movement rule's or band's collection is checked by the model.
#
# A new band, or one whose lines, finish or collection changed, is placed against today's prices
# straight away (PriceAlerts::SyncBand), in the same transaction, so its worklist is ready the moment
# it saves. `existing_cards: 'audit'` puts the cards already past the line on that list; anything
# else takes them as handled. A changed buylist range only narrows crossings from here on, so it
# leaves the cards where they are.
module PriceAlerts
  class Save < Service
    THRESHOLD_FIELDS = %i[finish direction threshold_price].freeze
    MOVEMENT_FIELDS = [:collection_id, :finish, :direction, :window, :min_delta_amount, :min_delta_percent,
                       :min_price, :min_buylist_price, :max_buylist_price, { rarities: [] }].freeze
    BAND_FIELDS = %i[collection_id finish direction threshold_price from_price min_buylist_price
                     max_buylist_price].freeze
    FIELDS = { 'threshold' => THRESHOLD_FIELDS, 'movement' => MOVEMENT_FIELDS, 'band' => BAND_FIELDS }.freeze
    TARGET_FIELDS = { 'threshold' => %i[magic_card_id scryfall_oracle_id], 'movement' => %i[magic_card_id] }.freeze
    # a band changed in any of these is placed afresh
    RESEED_FIELDS = %w[collection_id finish direction threshold_price from_price].freeze

    def initialize(user:, params:, alert: nil)
      @user = user
      @params = params
      @alert = alert
    end

    def call
      alert = @alert || @user.price_alerts.new(kind: @params[:kind].to_s)
      alert.assign_attributes(permitted(alert))

      { success: save(alert), alert: alert }
    end

    private

    def save(alert)
      PriceAlert.transaction do
        next false unless alert.save

        reseed(alert) if reseed?(alert)
        true
      end
    end

    def reseed?(alert)
      alert.band? && (alert.saved_change_to_id? || alert.saved_changes.keys.intersect?(RESEED_FIELDS))
    end

    # delete_all leaves band_cards loaded and empty, so it is reset once the sync has filled it
    def reseed(alert)
      alert.band_cards.delete_all
      SyncBand.call(band: alert, audit: @params[:existing_cards] == 'audit')
      alert.band_cards.reset
    end

    def permitted(alert)
      fields = FIELDS.fetch(alert.kind, MOVEMENT_FIELDS)
      extra = alert.new_record? ? TARGET_FIELDS.fetch(alert.kind, []) : [:active]

      @params.permit(*fields, *extra)
    end
  end
end
