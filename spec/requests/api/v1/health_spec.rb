require 'rails_helper'
require 'support/api/v1_helpers'

RSpec.describe 'API v1 health', type: :request do
  include_context 'api v1 request'

  it 'reports the api and minimum client version without a session' do
    get '/api/v1/health', headers: api_headers

    expect(response).to have_http_status(:ok)
    expect(json_body).to eq('status' => 'ok', 'api_version' => 'v1', 'min_client_version' => '0.1.0')
    expect(response.headers['Set-Cookie']).to be_blank
  end

  it 'answers JSON even when the client sends no Accept header' do
    get '/api/v1/health'

    expect(response.media_type).to eq('application/json')
  end

  # the real routes, not a with_routing set - proves the catch-all sits under the api namespace
  it 'renders an unknown api path as a JSON 404, not the HTML error page' do
    get '/api/v1/nope', headers: api_headers

    expect_api_error(:not_found, 'not_found')
  end
end
