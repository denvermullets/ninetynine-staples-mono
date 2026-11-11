require 'rails_helper'

RSpec.describe ApplicationCable::Connection, type: :channel do
  let(:user) { create(:user) }
  let(:issued) { ApiToken.issue!(user, name: 'Test client') }
  let(:token) { issued.first }
  let(:raw_token) { issued.last }

  def bearer(value)
    { 'Authorization' => "Bearer #{value}" }
  end

  it 'connects a valid token as current_user' do
    connect '/cable', headers: bearer(raw_token)

    expect(connection.current_user).to eq(user)
    expect(connection.api_token).to eq(token)
  end

  it 'rejects a missing token' do
    expect { connect '/cable' }.to have_rejected_connection
  end

  it 'rejects an unknown token' do
    expect { connect '/cable', headers: bearer('mtg_nope') }.to have_rejected_connection
  end

  it 'rejects an expired token' do
    token.update!(expires_at: 1.minute.ago)

    expect { connect '/cable', headers: bearer(raw_token) }.to have_rejected_connection
  end

  it 'rejects a revoked token' do
    token.revoke!

    expect { connect '/cable', headers: bearer(raw_token) }.to have_rejected_connection
  end

  it 'rejects a non-bearer scheme' do
    expect { connect '/cable', headers: { 'Authorization' => "Basic #{raw_token}" } }.to have_rejected_connection
  end

  it 'accepts a request with no Origin header' do
    env = Rack::MockRequest.env_for('/cable', 'HTTP_AUTHORIZATION' => "Bearer #{raw_token}")
    connection = described_class.new(ActionCable.server, env)

    expect(connection.send(:allow_request_origin?)).to be(true)
  end

  describe 'revoking a token' do
    let(:remote) { instance_double(ActionCable::RemoteConnections::RemoteConnection, disconnect: nil) }

    before do
      allow(ActionCable.server.remote_connections).to receive(:where).and_return(remote)
    end

    it 'disconnects that token\'s open connections' do
      token.revoke!

      expect(ActionCable.server.remote_connections).to have_received(:where).with(api_token: token)
      expect(remote).to have_received(:disconnect)
    end

    it 'disconnects every token revoked in bulk' do
      token
      other = ApiToken.issue!(user, name: 'Second').first
      user.api_tokens.revoke_all!

      expect(ActionCable.server.remote_connections).to have_received(:where).with(api_token: token)
      expect(ActionCable.server.remote_connections).to have_received(:where).with(api_token: other)
    end
  end
end
