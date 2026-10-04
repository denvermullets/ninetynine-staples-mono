require 'rails_helper'

RSpec.describe 'Users::PasswordResets', type: :request do
  let(:user) { create(:user) }
  let(:token) { user.generate_token_for(:password_reset) }
  let(:new_password) { { user: { password: 'newpassword456', password_confirmation: 'newpassword456' } } }

  it 'revokes every game client token on a successful reset' do
    raw_token = ApiToken.issue!(user, name: 'Steam Deck').last

    patch password_reset_path(token), params: new_password

    expect(response).to have_http_status(:see_other)
    expect(user.api_tokens.active).to be_empty

    get '/api/v1/me', headers: { 'Authorization' => "Bearer #{raw_token}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it 'leaves tokens alone when the reset link is invalid' do
    ApiToken.issue!(user, name: 'Steam Deck')

    patch password_reset_path('not-a-token'), params: new_password

    expect(user.api_tokens.active.count).to eq(1)
  end
end
