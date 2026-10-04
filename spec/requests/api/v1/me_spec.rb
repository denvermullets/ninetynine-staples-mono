require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 me', type: :request do
  include_context 'api v1 authenticated request'

  it 'returns the signed-in user with their preferences' do
    api_user.update!(theme: 'light')

    get '/api/v1/me', headers: api_headers

    expect(response).to have_http_status(:ok)
    expect(json_body).to include('id' => api_user.id, 'username' => api_user.username, 'email' => api_user.email)
    expect(json_body['preferences']).to include('theme' => 'light', 'collection_order' => [])
  end

  it 'records when the token was last used' do
    get '/api/v1/me', headers: api_headers

    expect(api_token.reload.last_used_at).to be_within(1.minute).of(Time.current)
  end

  it 'rejects a request with no token' do
    get '/api/v1/me', headers: { 'Accept' => 'application/json' }

    expect_api_error(:unauthorized, 'unauthorized')
    expect(response.headers['WWW-Authenticate']).to eq('Bearer')
  end

  it 'rejects an unknown token' do
    get '/api/v1/me', headers: { 'Authorization' => 'Bearer mtg_not-a-real-token' }

    expect_api_error(:unauthorized, 'unauthorized')
  end

  it 'rejects a revoked token' do
    api_token.revoke!

    get '/api/v1/me', headers: api_headers

    expect_api_error(:unauthorized, 'unauthorized')
  end

  it 'rejects an expired token' do
    api_token.update!(expires_at: 1.minute.ago)

    get '/api/v1/me', headers: api_headers

    expect_api_error(:unauthorized, 'unauthorized')
  end

  it 'rejects a token sent without the Bearer scheme' do
    get '/api/v1/me', headers: { 'Authorization' => raw_api_token }

    expect_api_error(:unauthorized, 'unauthorized')
  end
end
