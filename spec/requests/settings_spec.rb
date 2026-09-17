require 'rails_helper'

RSpec.describe 'Settings', type: :request do
  let(:user) { create(:user, username: 'trader') }

  describe 'POST /settings/update_trades_visibility' do
    it 'requires a login' do
      post update_trades_visibility_path, params: { public: true }, as: :json

      expect(user.reload.trades_public).to be(false)
    end

    context 'when logged in' do
      before { post login_path, params: { email: user.email, password: 'password123' } }

      it 'opens the trade list' do
        post update_trades_visibility_path, params: { public: true }, as: :json

        expect(response).to have_http_status(:ok)
        expect(user.reload.trades_public).to be(true)
      end

      it 'closes it again' do
        user.update!(trades_public: true)

        post update_trades_visibility_path, params: { public: false }, as: :json

        expect(user.reload.trades_public).to be(false)
      end
    end
  end
end
