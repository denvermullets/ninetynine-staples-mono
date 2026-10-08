require 'rails_helper'

# Nothing here renders the page - CI has no built tailwind.css - so what the list shows is covered by
# CollectionStats::SellList's spec, and this file is the seam around it: who may look, and where a
# stale link is sent.
RSpec.describe 'CollectionSell', type: :request do
  let(:user) { create(:user, username: 'owner') }
  let!(:collection) { create(:collection, user: user, is_public: true) }

  def sign_in(as)
    post login_path, params: { email: as.email, password: 'password123' }
  end

  it 'sends a logged-out visitor to the login page' do
    get collection_sell_path(user.username)

    expect(response).to redirect_to(login_path)
  end

  it "is a 404 on somebody else's cards, public or not" do
    sign_in(create(:user, username: 'visitor'))

    get collection_sell_path(user.username, collection_id: collection.id)

    expect(response).to have_http_status(:not_found)
  end

  context 'when signed in as the owner' do
    before { sign_in(user) }

    it 'will not list a collection belonging to another user' do
      theirs = create(:collection, user: create(:user, username: 'stranger'))

      get collection_sell_path(user.username, collection_id: theirs.id)

      expect(response).to redirect_to(collection_sell_path(user.username))
    end

    # the total counts every page, so a page past the end is a link from before the list shrank
    it 'sends a page past the end back to the first page, keeping the filters' do
      card = create(:magic_card, ck_buylist_normal_price: 1)
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 1)

      get collection_sell_path(user.username, collection_id: collection.id, payment: 'credit', page: 5)

      expect(response).to redirect_to(
        collection_sell_path(user.username, collection_id: collection.id, payment: 'credit')
      )
    end
  end
end
