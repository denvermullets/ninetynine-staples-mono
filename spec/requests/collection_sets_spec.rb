require 'rails_helper'

# Nothing here renders the page. A request spec that renders the full layout needs a built
# tailwind.css, which CI does not have, so what the page SHOWS is covered by the service specs
# (CollectionStats::SetDetail and ::SetCards) and what is left for this file is the seam around
# them: which set you are allowed to open, and whose collection it gets measured against.
RSpec.describe 'CollectionSets', type: :request do
  let(:user) { create(:user, username: 'owner') }
  let(:set) { create(:boxset, code: 'ALP') }
  let!(:collection) { create(:collection, user: user, is_public: true) }

  # The landing page, and the only route into this area that is not a link from somewhere else.
  describe 'index' do
    it 'refuses a username it does not have' do
      get collection_sets_path('nobody')

      expect(response).to have_http_status(:not_found)
    end

    # same rule as #show, and it has to drop the id rather than keep it or the redirect loops
    it 'will not measure against a collection belonging to another user' do
      stranger = create(:user, username: 'stranger')
      theirs = create(:collection, user: stranger, is_public: true)

      get collection_sets_path(user.username, collection_id: theirs.id)

      expect(response).to redirect_to(collection_sets_path(user.username))
    end

    it 'leaves a private collection out of what a visitor is shown' do
      private_collection = create(:collection, user: user, is_public: false)

      get collection_sets_path(user.username, collection_id: private_collection.id)

      expect(response).to redirect_to(collection_sets_path(user.username))
    end

    # /sets must not be swallowed by collections/:username(/:collection_id), which sits below it and
    # would happily read "sets" as a collection id
    it 'routes ahead of the collection show catch-all' do
      recognized = Rails.application.routes.recognize_path("/collections/#{user.username}/sets")

      expect(recognized).to include(controller: 'collection_sets', action: 'index')
    end
  end

  it 'refuses a set code it does not have' do
    get collection_set_path(user.username, 'NOPE')

    expect(response).to have_http_status(:not_found)
  end

  # Scope resolves the requested collection_id inside the collections it already loaded for this
  # username, so the page cannot be pointed at somebody else's binder by guessing an id. The bounce
  # drops the id rather than keeping it, or the redirect would loop.
  describe 'visibility' do
    it 'will not measure against a collection belonging to another user' do
      stranger = create(:user, username: 'stranger')
      theirs = create(:collection, user: stranger, is_public: true)

      get collection_set_path(user.username, set.code, collection_id: theirs.id)

      expect(response).to redirect_to(collection_set_path(user.username, set.code))
    end

    it 'leaves a private collection out of what a visitor is shown' do
      private_collection = create(:collection, user: user, is_public: false)

      get collection_set_path(user.username, set.code, collection_id: private_collection.id)

      expect(response).to redirect_to(collection_set_path(user.username, set.code))
    end
  end
end
