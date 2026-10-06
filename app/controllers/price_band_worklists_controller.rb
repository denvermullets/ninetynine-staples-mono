# A price band's worklist: the cards that crossed it and still need handling, with a tab for the ones
# already ticked off. The band is found through current_user.price_alerts, so someone else's is a 404,
# and so is an alert that is not a band.
#
# Ticking a card off (or back on, from the done tab) answers with a turbo stream that drops its row
# and recounts the tabs. "Mark all done" clears the whole list and reloads the page.
class PriceBandWorklistsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_band

  def show
    @done = params[:tab] == 'done'
    @rows = PriceAlerts::BandWorklist.call(band: @band, done: @done)
    @counts = counts
  end

  def update
    return mark_all_done if params[:all].present?

    band_card = @band.band_cards.listed.find_by(id: params[:band_card_id])
    return head :not_found unless band_card

    handled = params[:handled] != 'false'
    band_card.update!(handled_at: handled ? Time.current : nil)
    render_ticked(band_card, handled)
  end

  private

  # the row leaves whichever tab it was on, and the tab counts move with it
  def render_ticked(band_card, handled)
    tabs = turbo_stream.replace('worklist_tabs', partial: 'price_band_worklists/tabs',
                                                 locals: { band: @band, counts: counts, done: !handled })

    render turbo_stream: [turbo_stream.remove(helpers.dom_id(band_card)), tabs,
                          toast(handled ? 'Marked done.' : 'Back on the list.')]
  end

  def set_band
    @band = current_user.price_alerts.bands.find_by(id: params[:price_alert_id])
    head :not_found unless @band
  end

  def mark_all_done
    count = @band.band_cards.to_do.update_all(handled_at: Time.current, updated_at: Time.current)

    redirect_to price_alert_worklist_path(@band), notice: "Marked #{helpers.pluralize(count, 'card')} done.",
                                                  status: :see_other
  end

  def counts
    { to_do: @band.band_cards.to_do.count, done: @band.band_cards.done.count }
  end

  def toast(message)
    flash.now[:type] = 'success'
    turbo_stream.append('toasts', partial: 'shared/toast', locals: { message: message })
  end
end
