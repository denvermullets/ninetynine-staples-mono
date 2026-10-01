require 'rails_helper'

# CSV responses only - no layout renders here, CI has no built tailwind.css
RSpec.describe 'Collection exports', type: :request do
  let(:user) { create(:user) }
  let!(:collection) { create(:collection, user: user, name: 'Trade Binder', collection_type: 'binder') }

  def log_in(as)
    post login_path, params: { email: as.email, password: 'password123' }
  end

  it 'downloads one collection as a named CSV' do
    log_in(user)

    get collection_export_path(collection)

    expect(response.media_type).to eq('text/csv')
    expect(response.headers['Content-Disposition']).to include('attachment', 'trade-binder-')
    expect(response.body.lines.first).to start_with('Scryfall ID,')
  end

  it 'downloads every card with a Collections column' do
    log_in(user)

    get collection_exports_path

    expect(response.media_type).to eq('text/csv')
    expect(response.body.lines.first.strip).to end_with(',Collections')
  end

  it "does not export someone else's collection" do
    log_in(create(:user))

    get collection_export_path(collection)

    expect(response).to have_http_status(:not_found)
  end
end
