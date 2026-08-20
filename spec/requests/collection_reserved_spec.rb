require 'rails_helper'

# Nothing here renders the page. A request spec that renders the full layout needs a built
# tailwind.css, which CI does not have, so what the page SHOWS is covered by the service spec
# (CollectionStats::ReservedCards) and whose collections get counted is covered by
# CollectionStats::Scope's own spec. What is left for this file is the seam: the username has to be
# real, and the route has to win against the catch-all sitting under it.
#
# There is no collection_id case to cover, unlike the sets and proxies specs: this page is
# deliberately across ALL of a user's collections, so there is nothing to resolve and nothing to
# bounce.
RSpec.describe 'CollectionReserved', type: :request do
  let(:user) { create(:user, username: 'owner') }
  let!(:collection) { create(:collection, user: user, is_public: true) }

  it 'refuses a username it does not have' do
    get collection_reserved_path('nobody')

    expect(response).to have_http_status(:not_found)
  end

  # /reserved must not be swallowed by collections/:username(/:collection_id), which sits below it
  # and would happily read "reserved" as a collection id
  it 'routes ahead of the collection show catch-all' do
    recognized = Rails.application.routes.recognize_path("/collections/#{user.username}/reserved")

    expect(recognized).to include(controller: 'collection_reserved', action: 'show')
  end
end
