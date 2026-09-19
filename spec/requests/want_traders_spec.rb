require 'rails_helper'

# The page shell renders a layout CI cannot build, so the traders are asked for the way pagination
# asks for them - as a frame request. Who is listed and in what order is WantList::Traders' business.
RSpec.describe 'WantTraders', type: :request do
  let(:user) { create(:user, username: 'wanter') }
  let(:holder) { create(:user, username: 'holder', trades_public: true) }
  let(:card) { create(:magic_card) }
  let(:want) { create(:want_list_item, user: user, magic_card: card) }
  let(:frame) { { 'Turbo-Frame' => 'want_traders' } }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page' do
    get want_traders_path(want)

    expect(response).to redirect_to(login_path)
  end

  it 'serves the traders to a frame request' do
    create(:collection_magic_card, collection: create(:collection, user: holder, is_public: true),
                                   magic_card: card, quantity: 1, trade_quantity: 1)
    sign_in(user)

    get want_traders_path(want), headers: frame

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('holder')
  end

  it 'serves a frame request with nobody trading it' do
    sign_in(user)

    get want_traders_path(want), headers: frame

    expect(response).to have_http_status(:ok)
  end

  it 'sends somebody else\'s want back to the want list' do
    sign_in(holder)

    get want_traders_path(want), headers: frame

    expect(response).to redirect_to(collection_wants_path('holder'))
  end

  it 'sends a page past the end back to the first' do
    sign_in(user)

    get want_traders_path(want, page: 5), headers: frame

    expect(response).to redirect_to(want_traders_path(want))
  end
end
