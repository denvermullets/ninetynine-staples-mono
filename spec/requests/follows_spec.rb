require 'rails_helper'

# The page shell renders a layout CI cannot build, so the list is asked for as a frame request,
# which renders no layout. Follow and unfollow only ever redirect.
RSpec.describe 'Follows', type: :request do
  let(:user) { create(:user, username: 'follower') }
  let!(:other) { create(:user, username: 'other.person') }
  let(:frame) { { 'Turbo-Frame' => 'follows' } }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page' do
    get following_path
    expect(response).to redirect_to(login_path)

    post follows_path, params: { username: other.username }
    expect(response).to redirect_to(login_path)
    expect(Follow.count).to eq(0)
  end

  it 'serves both tabs to a frame request' do
    create(:follow, follower: user, followed: other)
    create(:follow, follower: other, followed: user)
    sign_in(user)

    get following_path, headers: frame
    expect(response).to have_http_status(:ok)
    expect(response.body).to include('other.person')

    get following_path(tab: 'followers'), headers: frame
    expect(response).to have_http_status(:ok)
  end

  it 'serves a frame request with nobody followed' do
    sign_in(user)

    get following_path, headers: frame

    expect(response).to have_http_status(:ok)
  end

  it 'follows by username, whatever the case, and only once' do
    sign_in(user)

    2.times { post follows_path, params: { username: ' Other.Person ' } }

    expect(response).to redirect_to(following_path)
    expect(user.following.to_a).to eq([other])
  end

  it 'goes back to the page the button was on' do
    sign_in(user)

    post follows_path, params: { username: other.username },
                       headers: { 'HTTP_REFERER' => collection_trades_url(other.username) }

    expect(response).to redirect_to(collection_trades_url(other.username))
  end

  it 'refuses an unknown username and the user themselves' do
    sign_in(user)

    post follows_path, params: { username: 'nobody' }
    post follows_path, params: { username: user.username }

    expect(Follow.count).to eq(0)
  end

  it 'unfollows, and leaves other people\'s follows alone' do
    create(:follow, follower: user, followed: other)
    create(:follow, follower: other, followed: user)
    sign_in(user)

    delete follows_path, params: { username: other.username }

    expect(response).to redirect_to(following_path)
    expect([user.following?(other), other.following?(user)]).to eq([false, true])
  end
end
