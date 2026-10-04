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

  describe 'POST /settings/update_wants_visibility' do
    it 'requires a login' do
      post update_wants_visibility_path, params: { public: true }, as: :json

      expect(user.reload.wants_public).to be(false)
    end

    context 'when logged in' do
      before { post login_path, params: { email: user.email, password: 'password123' } }

      it 'opens the want list' do
        post update_wants_visibility_path, params: { public: true }, as: :json

        expect(response).to have_http_status(:ok)
        expect(user.reload.wants_public).to be(true)
      end

      it 'closes it again' do
        user.update!(wants_public: true)

        post update_wants_visibility_path, params: { public: false }, as: :json

        expect(user.reload.wants_public).to be(false)
      end
    end
  end

  describe 'game client sessions' do
    let(:turbo_stream) { { 'Accept' => 'text/vnd.turbo-stream.html' } }
    let!(:token) { ApiToken.issue!(user, name: 'Steam Deck').first }
    let!(:other_token) { ApiToken.issue!(user, name: 'Desktop').first }

    it 'requires a login' do
      delete revoke_api_token_path(token), headers: turbo_stream

      expect(token.reload.revoked_at).to be_nil
    end

    context 'when logged in' do
      before { post login_path, params: { email: user.email, password: 'password123' } }

      it 'revokes one token and re-renders the list without it' do
        delete revoke_api_token_path(token), headers: turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
        expect(response.body).to include('Desktop')
        expect(response.body).not_to include('Steam Deck')
        expect(token.reload.revoked_at).to be_present
        expect(other_token.reload.revoked_at).to be_nil
      end

      it 'redirects back to the section without turbo' do
        delete revoke_api_token_path(token)

        expect(response).to redirect_to(settings_path(anchor: 'game-sessions'))
      end

      it "can't revoke someone else's token" do
        stranger_token = ApiToken.issue!(create(:user), name: 'Theirs').first

        delete revoke_api_token_path(stranger_token), headers: turbo_stream

        expect(response).to have_http_status(:not_found)
        expect(stranger_token.reload.revoked_at).to be_nil
      end

      it 'revokes all tokens' do
        delete revoke_all_api_tokens_path, headers: turbo_stream

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('No game clients are logged in')
        expect(user.api_tokens.active).to be_empty
      end

      it 'locks a revoked token out of the API' do
        raw_token = ApiToken.issue!(user, name: 'Laptop').last
        laptop = ApiToken.find_active(raw_token)

        delete revoke_api_token_path(laptop), headers: turbo_stream
        get '/api/v1/me', headers: { 'Authorization' => "Bearer #{raw_token}" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
