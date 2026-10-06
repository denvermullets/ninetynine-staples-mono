require 'rails_helper'

# Only the paths that render no layout: the login redirect, the 404s for what is not yours, and the
# turbo stream a movement rule answers with. Which fields a write keeps is covered in
# spec/services/price_alerts/save_spec.rb.
RSpec.describe 'PriceAlerts', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:card) { create(:magic_card) }
  let!(:someone_elses) { create(:price_alert, user: other_user, magic_card: card) }

  def log_in
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page without creating anything' do
    expect do
      post price_alerts_path, params: { price_alert: { kind: 'threshold', magic_card_id: card.id,
                                                       direction: 'above', threshold_price: '5' } },
                              as: :turbo_stream
    end.not_to change(PriceAlert, :count)

    expect(response).to redirect_to(login_path)
  end

  context 'when logged in' do
    before { log_in }

    it "404s the modal for someone else's want" do
      get new_price_alert_path(want_list_item_id: create(:want_list_item, user: other_user).id)

      expect(response).to have_http_status(:not_found)
    end

    it '404s the modal for an unknown card' do
      get new_price_alert_path(magic_card_id: 0)

      expect(response).to have_http_status(:not_found)
    end

    it "404s editing someone else's alert" do
      get edit_price_alert_path(someone_elses)

      expect(response).to have_http_status(:not_found)
    end

    it "404s updating someone else's alert and leaves it alone" do
      patch price_alert_path(someone_elses), params: { price_alert: { active: 'false' } }, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
      expect(someone_elses.reload).to be_active
    end

    # the movers page's "alert me" button: the stream is two partials, nothing in a layout
    it 'saves a movement rule and turns the movers button to "Alert on"' do
      expect do
        post price_alerts_path, params: { price_alert: { kind: 'movement', window: 'daily', direction: 'up',
                                                         finish: 'any', min_delta_amount: '5' } },
                                as: :turbo_stream
      end.to change(user.price_alerts.movement_rules, :count).by(1)

      expect(response.body).to include('target="movers_alert"', 'Alert on', price_alerts_path)
    end

    it "will not narrow a movement rule to someone else's collection" do
      expect do
        post price_alerts_path, params: { price_alert: { kind: 'movement', window: 'daily', direction: 'up',
                                                         finish: 'any', min_delta_amount: '5',
                                                         collection_id: create(:collection, user: other_user).id } },
                                as: :turbo_stream
      end.not_to change(PriceAlert, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'opens the new price band modal' do
      get new_price_alert_path(kind: 'band')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New price band', 'price_alert[from_price]', 'price_alert[existing_cards]')
    end

    it 'creates a price band and goes to its worklist' do
      expect do
        post price_alerts_path, params: { price_alert: { kind: 'band', direction: 'above', finish: 'any',
                                                         from_price: '0.90', threshold_price: '1.00' } }
      end.to change(user.price_alerts.bands, :count).by(1)

      expect(response).to redirect_to(price_alert_worklist_path(user.price_alerts.bands.sole))
    end

    it "404s deleting someone else's alert and leaves it alone" do
      expect { delete price_alert_path(someone_elses), as: :turbo_stream }.not_to change(PriceAlert, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
