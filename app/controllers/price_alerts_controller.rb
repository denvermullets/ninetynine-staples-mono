# The signed-in user's price alerts. Everything is found through current_user.price_alerts, so
# someone else's alert is a 404.
#
# new and edit answer with the modal, loaded into the layout's price_alert_modal frame: new from a
# bell (price_alerts/_bell) for a printing or a want, edit from a row on the index. The writes answer
# with turbo streams that close the modal, patch the index row and every bell on the page watching the
# same card, and toast. A failed write leaves the modal open and toasts the errors.
#
# The fields a write may set depend on the kind; anything else in the params is dropped. An alert never
# changes what it watches once made, so the card and oracle ids are only accepted on create.
class PriceAlertsController < ApplicationController
  THRESHOLD_FIELDS = %i[finish direction threshold_price].freeze
  MOVEMENT_FIELDS = %i[collection_id finish direction window min_delta_amount min_delta_percent min_price].freeze
  TARGET_FIELDS = { 'threshold' => %i[magic_card_id scryfall_oracle_id], 'movement' => %i[magic_card_id] }.freeze

  before_action :authenticate_user!
  before_action :set_alert, only: %i[edit update destroy]

  def index
    alerts = current_user.price_alerts.includes(:collection, magic_card: :boxset).order(:created_at).to_a
    @thresholds = alerts.select(&:threshold?)
    @rules = alerts.select(&:movement_rule?)
    @overrides = alerts.select { |alert| alert.movement? && !alert.movement_rule? }
    @cheapest = PriceAlert.cheapest_printings(@thresholds.filter_map(&:scryfall_oracle_id).uniq)
  end

  def new
    alert = bell_alert
    return head :not_found unless alert

    alert.threshold_price = alert.current_price
    render_modal(alert, existing: watching(alert), override: override_for(alert))
  end

  def edit
    render_modal(@alert)
  end

  def create
    kind = params.dig(:price_alert, :kind).to_s
    alert = current_user.price_alerts.new(kind: kind)
    alert.assign_attributes(alert_params(kind, TARGET_FIELDS.fetch(kind, [])))
    return render_errors(alert) unless alert.save

    render_saved(alert, "#{alert.threshold? ? 'Price' : 'Movement'} alert created.")
  end

  def update
    return render_errors(@alert) unless @alert.update(alert_params(@alert.kind, [:active]))

    message = if @alert.saved_change_to_active? then @alert.active? ? 'Alert resumed.' : 'Alert paused.'
              else 'Alert updated.'
              end
    render_saved(@alert, message, row: true)
  end

  def destroy
    @alert.destroy!

    render turbo_stream: [turbo_stream.remove(helpers.dom_id(@alert)),
                          turbo_stream.remove(helpers.dom_id(@alert, :modal)),
                          *bell_streams(@alert), toast('Alert deleted.')]
  end

  private

  def set_alert
    @alert = current_user.price_alerts.find_by(id: params[:id])
    head :not_found unless @alert
  end

  # An unsaved threshold alert for what the bell was pressed on: a want, watched the way the want
  # matches, or one printing in the given finish.
  def bell_alert
    if params[:want_list_item_id].present?
      item = current_user.want_list_items.find_by(id: params[:want_list_item_id])
      item && PriceAlert.threshold_for_want(item, threshold_price: nil, direction: 'above')
    elsif (card = MagicCard.find_by(id: params[:magic_card_id]))
      finish = PriceAlert::PRINTING_FINISHES.include?(params[:finish]) ? params[:finish] : 'normal'
      current_user.price_alerts.new(kind: 'threshold', magic_card: card, finish: finish, direction: 'above')
    end
  end

  # every alert already on the same card, listed in the modal so a second bell press can remove one
  def watching(alert)
    current_user.price_alerts.where(magic_card_id: alert.magic_card_id, scryfall_oracle_id: alert.scryfall_oracle_id)
                .order(:created_at)
  end

  # a per-card movement override needs a printing; an any-printing want has none to offer
  def override_for(alert)
    return unless alert.magic_card_id

    current_user.price_alerts.new(kind: 'movement', magic_card_id: alert.magic_card_id, finish: alert.finish,
                                  window: 'weekly', direction: 'both')
  end

  def render_modal(alert, existing: [], override: nil)
    render partial: 'price_alerts/modal', locals: { alert: alert, existing: existing, override: override }
  end

  def alert_params(kind, extra)
    fields = kind == 'threshold' ? THRESHOLD_FIELDS : MOVEMENT_FIELDS
    params.fetch(:price_alert, {}).permit(*fields, *extra)
  end

  def render_saved(alert, message, row: false)
    streams = [turbo_stream.update('price_alert_modal', ''), *bell_streams(alert), toast(message)]
    if row
      streams.unshift(turbo_stream.replace(helpers.dom_id(alert), partial: 'price_alerts/row',
                                                                  locals: { alert: alert }))
    end

    render turbo_stream: streams
  end

  def render_errors(alert)
    render turbo_stream: toast(alert.errors.full_messages.to_sentence, type: 'error'), status: :unprocessable_content
  end

  # Every bell on the page for the same card, which may sit in both the table and the mobile list.
  # Only thresholds light a bell, so a movement alert changes none.
  #
  # action_all(:update) is what turbo_stream.update_all calls; spelled out because Brakeman reads an
  # update_all with an interpolated string as ActiveRecord SQL. The selector is a CSS one, keyed by the
  # alert's own card id or oracle uuid.
  def bell_streams(alert)
    return [] unless alert.threshold?

    target = alert.slice(:magic_card_id, :scryfall_oracle_id).compact
    watched = current_user.price_alerts.active.thresholds.exists?(target)
    key = helpers.price_alert_bell_key(**alert.slice(:magic_card_id, :scryfall_oracle_id).symbolize_keys)

    [turbo_stream.action_all(:update, "[data-price-alert-bell=\"#{key}\"]",
                             partial: 'price_alerts/bell_icon', locals: { watched: watched })]
  end

  def toast(message, type: 'success')
    flash.now[:type] = type
    turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
  end
end
