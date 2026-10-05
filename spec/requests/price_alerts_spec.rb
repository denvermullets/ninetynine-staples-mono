require 'rails_helper'

# GET /price_alerts renders a layout CI cannot build, so only the modal (a partial) and the writes (turbo
# streams) are requested here.
RSpec.describe 'PriceAlerts', type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:card) { create(:magic_card, normal_price: 12, foil_price: 30) }
  let(:alert) { create(:price_alert, user: user, magic_card: card, threshold_price: 20) }
  let(:someone_elses) { create(:price_alert, user: other_user, magic_card: card) }

  def log_in(as = user)
    post login_path, params: { email: as.email, password: 'password123' }
  end

  def threshold_params(**overrides)
    { price_alert: { kind: 'threshold', magic_card_id: card.id, finish: 'foil', direction: 'above',
                     threshold_price: '40' }.merge(overrides) }
  end

  it 'sends a logged-out visitor to the login page' do
    expect { post price_alerts_path, params: threshold_params, as: :turbo_stream }.not_to change(PriceAlert, :count)

    expect(response).to redirect_to(login_path)
  end

  describe 'GET /price_alerts/new' do
    before { log_in }

    it 'opens the modal for a printing, prefilled with its price in that finish' do
      get new_price_alert_path(magic_card_id: card.id, finish: 'foil')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('price_alert_modal', 'value="30.00"')
    end

    it 'opens the modal for one of your wants' do
      item = create(:want_list_item, user: user, magic_card: card, any_printing: false)

      get new_price_alert_path(want_list_item_id: item.id)

      expect(response).to have_http_status(:ok)
    end

    it "404s on someone else's want" do
      item = create(:want_list_item, user: other_user, magic_card: card)

      get new_price_alert_path(want_list_item_id: item.id)

      expect(response).to have_http_status(:not_found)
    end

    it '404s on an unknown card' do
      get new_price_alert_path(magic_card_id: 0)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /price_alerts/:id/edit' do
    before { log_in }

    it 'opens the modal for your own alert' do
      get edit_price_alert_path(alert)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Edit alert')
    end

    it "404s on someone else's alert" do
      get edit_price_alert_path(someone_elses)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /price_alerts' do
    before { log_in }

    it 'creates a threshold alert for the current user and lights the bell' do
      expect { post price_alerts_path, params: threshold_params, as: :turbo_stream }
        .to change(user.price_alerts, :count).by(1)

      created = user.price_alerts.last
      expect(created).to have_attributes(kind: 'threshold', magic_card_id: card.id, finish: 'foil',
                                         direction: 'above', threshold_price: 40, last_side: 'below')
      expect(response.body).to include("card-#{card.id}")
    end

    it 'drops fields a threshold alert does not take' do
      post price_alerts_path, params: threshold_params(window: 'daily', min_delta_amount: '5', active: 'false',
                                                       user_id: other_user.id, last_fired_at: 1.day.ago),
                              as: :turbo_stream

      expect(user.price_alerts.last).to have_attributes(window: nil, min_delta_amount: nil, active: true,
                                                        last_fired_at: nil)
      expect(other_user.price_alerts).to be_empty
    end

    it 'creates a per-card movement override' do
      post price_alerts_path, params: { price_alert: { kind: 'movement', magic_card_id: card.id, finish: 'any',
                                                       direction: 'both', window: 'weekly',
                                                       min_delta_amount: '5' } },
                              as: :turbo_stream

      expect(user.price_alerts.card_overrides.sole).to have_attributes(magic_card_id: card.id, window: 'weekly')
    end

    it "refuses a movement rule on someone else's collection, with an error toast" do
      collection = create(:collection, user: other_user)

      expect do
        post price_alerts_path, params: { price_alert: { kind: 'movement', collection_id: collection.id,
                                                         direction: 'both', window: 'daily', min_delta_amount: '5' } },
                                as: :turbo_stream
      end.not_to change(PriceAlert, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('must be one of your collections')
    end

    it 'refuses an unknown kind' do
      expect { post price_alerts_path, params: threshold_params(kind: 'bogus'), as: :turbo_stream }
        .not_to change(PriceAlert, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH /price_alerts/:id' do
    before { log_in }

    it 'updates the condition and re-renders the row' do
      patch price_alert_path(alert), params: { price_alert: { threshold_price: '8', direction: 'below' } },
                                     as: :turbo_stream

      expect(alert.reload).to have_attributes(threshold_price: 8, direction: 'below', last_side: 'above')
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(alert))
    end

    it 'pauses an alert and unlights the bell' do
      patch price_alert_path(alert), params: { price_alert: { active: 'false' } }, as: :turbo_stream

      expect(alert.reload).not_to be_active
      expect(response.body).to include('Alert paused.', 'Set a price alert')
    end

    it 'never moves an alert to another card' do
      other_card = create(:magic_card)

      patch price_alert_path(alert), params: { price_alert: { magic_card_id: other_card.id } }, as: :turbo_stream

      expect(alert.reload.magic_card_id).to eq(card.id)
    end

    it "404s on someone else's alert" do
      patch price_alert_path(someone_elses), params: { price_alert: { active: 'false' } }, as: :turbo_stream

      expect(response).to have_http_status(:not_found)
      expect(someone_elses.reload).to be_active
    end
  end

  describe 'DELETE /price_alerts/:id' do
    before { log_in }

    it 'deletes your own alert' do
      alert

      expect { delete price_alert_path(alert), as: :turbo_stream }.to change(PriceAlert, :count).by(-1)
      expect(response.body).to include('Alert deleted.')
    end

    it "404s on someone else's alert" do
      someone_elses

      expect { delete price_alert_path(someone_elses), as: :turbo_stream }.not_to change(PriceAlert, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
