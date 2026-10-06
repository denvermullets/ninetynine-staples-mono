require 'rails_helper'

# Only what renders no layout: the 404s, the turbo stream a tick answers with, and the redirect after
# "mark all done". What the list holds is covered in spec/services/price_alerts/band_worklist_spec.rb.
RSpec.describe 'PriceBandWorklists', type: :request do
  let(:user) { create(:user) }
  let(:band) { create(:price_alert, :band, user: user) }
  let!(:to_do) { create(:price_band_card, :to_do, band: band) }

  def log_in
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page without ticking anything' do
    patch price_alert_worklist_path(band), params: { band_card_id: to_do.id }, as: :turbo_stream

    expect(response).to redirect_to(login_path)
    expect(to_do.reload.handled_at).to be_nil
  end

  context 'when logged in' do
    before { log_in }

    it "404s someone else's band and leaves its list alone" do
      theirs = create(:price_band_card, :to_do)

      patch price_alert_worklist_path(theirs.band), params: { all: 1 }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.handled_at).to be_nil
    end

    it '404s a worklist for an alert that is not a band' do
      get price_alert_worklist_path(create(:price_alert, user: user))

      expect(response).to have_http_status(:not_found)
    end

    it "404s ticking a card on another band's list" do
      other = create(:price_band_card, :to_do, band: create(:price_alert, :band, user: user))

      patch price_alert_worklist_path(band), params: { band_card_id: other.id }, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
      expect(other.reload.handled_at).to be_nil
    end

    it 'ticks a card off, dropping its row and recounting the tabs' do
      patch price_alert_worklist_path(band), params: { band_card_id: to_do.id }, as: :turbo_stream

      expect(to_do.reload.handled_at).to be_present
      expect(response.body).to include(%(action="remove" target="#{ActionView::RecordIdentifier.dom_id(to_do)}"),
                                       'To do (0)', 'Done (1)')
    end

    it 'puts a done card back on the list' do
      to_do.update!(handled_at: Time.current)

      patch price_alert_worklist_path(band), params: { band_card_id: to_do.id, handled: 'false' }, as: :turbo_stream

      expect(to_do.reload.handled_at).to be_nil
    end

    it 'marks the whole list done and goes back to it' do
      create(:price_band_card, :to_do, band: band)

      patch price_alert_worklist_path(band), params: { all: 1 }

      expect(response).to redirect_to(price_alert_worklist_path(band))
      expect(band.band_cards.to_do).to be_empty
    end
  end
end
