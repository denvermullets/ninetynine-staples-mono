# Shared bits for spec/requests/api/v1. Require it from the spec:
#   require 'support/api/v1_helpers'
# The bearer-token context (an `api_headers` with Authorization) lands with token auth
module ApiV1Helpers
  def json_body
    JSON.parse(response.body)
  end

  def expect_api_error(status, code)
    expect(response).to have_http_status(status)
    expect(response.media_type).to eq('application/json')
    expect(json_body['error']).to include('code' => code, 'message' => a_kind_of(String))
  end
end

RSpec.shared_context 'api v1 request' do
  include ApiV1Helpers

  let(:api_headers) { { 'Accept' => 'application/json' } }
end
