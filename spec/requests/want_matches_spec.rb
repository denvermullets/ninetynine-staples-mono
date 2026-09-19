require 'rails_helper'

# The page shell renders a layout CI cannot build, so the matches are asked for the way pagination
# asks for them - as a frame request, which renders no layout. What each holder is matched on is
# WantList::Matches' business and covered there; the builder pre-seed is Trades::WantDraft's.
RSpec.describe 'WantMatches', type: :request do
  let(:user) { create(:user, username: 'wanter') }
  let(:holder) { create(:user, username: 'holder', trades_public: true) }
  let(:frame) { { 'Turbo-Frame' => 'want_matches' } }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page' do
    get want_matches_path

    expect(response).to redirect_to(login_path)
  end

  it 'serves the matches to a frame request' do
    card = create(:magic_card)
    create(:want_list_item, user: user, magic_card: card)
    create(:collection_magic_card, collection: create(:collection, user: holder, is_public: true),
                                   magic_card: card, quantity: 1, trade_quantity: 1)
    sign_in(user)

    get want_matches_path, headers: frame

    expect(response).to have_http_status(:ok)
  end

  it 'serves a frame request with nothing matched' do
    sign_in(user)

    get want_matches_path, headers: frame

    expect(response).to have_http_status(:ok)
  end

  it 'sends a page past the end back to the first' do
    sign_in(user)

    get want_matches_path(page: 5), headers: frame

    expect(response).to redirect_to(want_matches_path)
  end
end
