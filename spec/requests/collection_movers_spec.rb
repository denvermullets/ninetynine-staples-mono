require 'rails_helper'

# Nothing here renders the page. A request spec that renders the full layout needs a built
# tailwind.css, which CI does not have, so what the table SHOWS is covered by the service spec
# (CollectionStats::MoversTable) and what is left for this file is the seam around it: whose cards
# you are allowed to look at, and where a stale link gets sent.
RSpec.describe 'CollectionMovers', type: :request do
  let(:user) { create(:user, username: 'owner') }
  let!(:collection) { create(:collection, user: user, is_public: true) }

  it 'refuses a username it does not have' do
    get collection_movers_path('nobody')

    expect(response).to have_http_status(:not_found)
  end

  describe 'visibility' do
    it 'will not list moves from a collection belonging to another user' do
      stranger = create(:user, username: 'stranger')
      theirs = create(:collection, user: stranger, is_public: true)

      get collection_movers_path(user.username, collection_id: theirs.id)

      expect(response).to redirect_to(collection_movers_path(user.username))
    end

    it 'leaves a private collection out of what a visitor is shown' do
      private_collection = create(:collection, user: user, is_public: false)

      get collection_movers_path(user.username, collection_id: private_collection.id)

      expect(response).to redirect_to(collection_movers_path(user.username))
    end
  end

  # the total counts every page, so a page past the end is a link from before the list shrank
  it 'sends a page past the end back to the first page, keeping the filters' do
    card = create(:magic_card, normal_price: 110, price_change_weekly_normal: 10)
    create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)

    get collection_movers_path(user.username, collection_id: collection.id, direction: 'up', page: 5)

    expect(response).to redirect_to(
      collection_movers_path(user.username, collection_id: collection.id, direction: 'up')
    )
  end
end
