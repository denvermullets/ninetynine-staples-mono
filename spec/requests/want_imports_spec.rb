require 'rails_helper'

# Answered with turbo streams of partials, so these render no layout. The adding happens in
# WantImportJob, covered in its own spec; here it only has to be enqueued for the right user.
RSpec.describe 'WantImports', type: :request do
  let(:user) { create(:user, username: 'wanter') }

  def sign_in(user)
    post login_path, params: { email: user.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page' do
    post want_imports_path, params: { decklist: '1 Sol Ring' }

    expect(response).to redirect_to(login_path)
  end

  it 'enqueues the paste for the signed-in user and answers with the pending panel' do
    sign_in(user)

    expect { post want_imports_path, params: { decklist: '1 Sol Ring' }, as: :turbo_stream }
      .to have_enqueued_job(WantImportJob).with(user.id, collection_wants_path(user.username), decklist: '1 Sol Ring')

    expect(response.media_type).to eq(Mime[:turbo_stream])
    expect(response.body).to include('Adding to your want list')
    expect(user.want_list_items.count).to eq(0)
  end

  it 'hands the job the filter and sort of the page it was sent from' do
    sign_in(user)
    page = collection_wants_url(user.username, filter: 'unfilled', sort: 'name', page: 3)

    expect do
      post want_imports_path, params: { decklist: '1 Sol Ring' }, headers: { 'Referer' => page }, as: :turbo_stream
    end
      .to have_enqueued_job(WantImportJob)
      .with(user.id, collection_wants_path(user.username, filter: 'unfilled', sort: 'name'), decklist: '1 Sol Ring')
  end

  describe 'adding proxies' do
    it 'sends a logged-out visitor to the login page' do
      post want_proxy_imports_path

      expect(response).to redirect_to(login_path)
    end

    it 'enqueues the import for the signed-in user, with no decklist' do
      sign_in(user)

      expect { post want_proxy_imports_path, as: :turbo_stream }
        .to have_enqueued_job(WantImportJob).with(user.id, collection_wants_path(user.username))

      expect(response.media_type).to eq(Mime[:turbo_stream])
    end
  end
end
