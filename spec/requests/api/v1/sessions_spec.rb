require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 sessions', type: :request do
  include_context 'api v1 request'

  let!(:user) { create(:user, email: 'player@example.com', password: 'correct-horse') }

  def log_in(email: user.email, password: 'correct-horse', **extra)
    post '/api/v1/sessions', params: { email: email, password: password, **extra }, as: :json
  end

  describe 'POST /api/v1/sessions' do
    it 'issues a token for valid credentials' do
      log_in(device_name: 'Manhattan desktop - MacBook')

      expect(response).to have_http_status(:created)
      expect(json_body['token']).to start_with('mtg_')
      expect(Time.zone.parse(json_body['expires_at'])).to be_within(1.minute).of(90.days.from_now)
      expect(json_body['user']).to eq('id' => user.id, 'username' => user.username, 'email' => user.email)
      expect(response.headers['Set-Cookie']).to be_blank

      token = user.api_tokens.sole
      expect(token.name).to eq('Manhattan desktop - MacBook')
      expect(ApiToken.find_active(json_body['token'])).to eq(token)
    end

    it 'matches the email case-insensitively and names the token when no device is sent' do
      log_in(email: ' Player@Example.com ')

      expect(response).to have_http_status(:created)
      expect(user.api_tokens.sole.name).to eq('Game client')
    end

    it 'rejects a wrong password with 401 invalid_credentials' do
      log_in(password: 'wrong-password')

      expect_api_error(:unauthorized, 'invalid_credentials')
      expect(ApiToken.count).to eq(0)
    end

    it 'rejects an unknown email the same way' do
      log_in(email: 'nobody@example.com')

      expect_api_error(:unauthorized, 'invalid_credentials')
    end

    it 'requires a password' do
      post '/api/v1/sessions', params: { email: user.email }, as: :json

      expect_api_error(:unprocessable_content, 'parameter_missing')
    end

    it 'throttles the 11th login from one IP in 15 minutes' do
      10.times { log_in(password: 'wrong-password') }
      expect(response).to have_http_status(:unauthorized)

      log_in

      expect_api_error(:too_many_requests, 'throttled')
    end

    it 'throttles the 11th login for one email across IPs' do
      10.times do |i|
        post '/api/v1/sessions', params: { email: user.email, password: 'wrong-password' }, as: :json,
                                 env: { 'REMOTE_ADDR' => "10.0.0.#{i + 1}" }
      end

      post '/api/v1/sessions', params: { email: user.email.upcase, password: 'correct-horse' }, as: :json,
                               env: { 'REMOTE_ADDR' => '10.0.1.1' }

      expect_api_error(:too_many_requests, 'throttled')
    end
  end

  describe 'DELETE /api/v1/sessions' do
    include_context 'api v1 authenticated request'

    it 'revokes the current token only' do
      _other_token, other_raw = ApiToken.issue!(api_user, name: 'Other device')

      delete '/api/v1/sessions', headers: api_headers

      expect(response).to have_http_status(:no_content)
      expect(api_token.reload.revoked_at).to be_present
      expect(ApiToken.find_active(other_raw)).to be_present

      get '/api/v1/me', headers: api_headers
      expect_api_error(:unauthorized, 'unauthorized')
    end

    it 'needs a token' do
      delete '/api/v1/sessions'

      expect_api_error(:unauthorized, 'unauthorized')
    end
  end

  it 'keeps the password and token out of the logs' do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter('password' => 'x', 'token' => 'y')).to eq('password' => '[FILTERED]', 'token' => '[FILTERED]')
  end
end
