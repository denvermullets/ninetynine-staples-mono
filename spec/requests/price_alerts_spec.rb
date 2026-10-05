require 'rails_helper'

# Only the paths that render nothing: the login redirect and the 404s for what is not yours. Which
# fields a write keeps is covered in spec/services/price_alerts/save_spec.rb.
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

    it "404s deleting someone else's alert and leaves it alone" do
      expect { delete price_alert_path(someone_elses), as: :turbo_stream }.not_to change(PriceAlert, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
