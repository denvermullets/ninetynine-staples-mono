require 'rails_helper'

# Nothing here renders the page - see CollectionTrades::Access and CollectionTrades::List for who
# can see it and what it lists. What is left is the seam that does not render: the 404 and the bounce.
RSpec.describe 'CollectionTrades', type: :request do
  let(:user) { create(:user, username: 'trader') }

  it 'refuses a username it does not have' do
    get collection_trades_path('nobody')

    expect(response).to have_http_status(:not_found)
  end

  # these double as the route-order check: under the collections#show catch-all, 'trades' would be
  # read as a collection_id and the page would render instead of bouncing
  describe 'a private trade list' do
    it 'bounces a logged-out visitor' do
      get collection_trades_path(user.username)

      expect(response).to redirect_to(root_path)
    end

    it 'bounces another user' do
      visitor = create(:user, username: 'visitor')
      post login_path, params: { email: visitor.email, password: 'password123' }

      get collection_trades_path(user.username)

      expect(response).to redirect_to(root_path)
    end
  end
end
