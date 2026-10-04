# Shared bits for spec/requests/api/v1. Require it from the spec:
#   require 'support/api/v1_helpers'
require 'support/api/schemas'

module ApiV1Helpers
  def json_body
    JSON.parse(response.body)
  end

  def expect_api_error(status, code)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq('application/json')
    expect(json_body['error']).to include('code' => code, 'message' => a_kind_of(String))
    expect(json_body).to match_api_schema(:error)
  end
end

RSpec.shared_context 'api v1 request' do
  include ApiV1Helpers

  let(:api_headers) { { 'Accept' => 'application/json' } }
end

# signed in as api_user with a fresh token. api_token is the record, raw_api_token the bearer value
RSpec.shared_context 'api v1 authenticated request' do
  include_context 'api v1 request'

  let(:api_user) { create(:user) }
  let(:issued_api_token) { ApiToken.issue!(api_user, name: 'Spec client') }
  let(:api_token) { issued_api_token.first }
  let(:raw_api_token) { issued_api_token.last }
  let(:api_headers) { { 'Accept' => 'application/json', 'Authorization' => "Bearer #{raw_api_token}" } }
end
