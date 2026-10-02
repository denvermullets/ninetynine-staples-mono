require 'rails_helper'

# the frame a mobile card loads when it expands - rendered on its own, no layout
RSpec.describe 'Mobile card locations', type: :request do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, name: 'Binder') }
  let(:oracle_id) { SecureRandom.uuid }
  let(:card) { create(:magic_card, scryfall_oracle_id: oracle_id) }

  context 'when signed in' do
    before { post login_path, params: { email: user.email, password: 'password123' } }

    it 'lists each collection holding the card with its actions' do
      create(:collection_magic_card, collection: collection, magic_card: card, quantity: 2)

      get mobile_card_locations_path(card.id)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("mobile_locations_#{card.id}", 'Binder', 'Transfer', 'Adjust', 'Trade')
    end

    it 'offers the add picker when the card is in none of them' do
      collection

      get mobile_card_locations_path(card.id)

      expect(response.body).to include('Not in any of your collections yet.', 'Add to collection...')
    end

    it 'shows other printings the viewer owns' do
      other_printing = create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset))
      create(:collection_magic_card, collection: collection, magic_card: other_printing, quantity: 1)

      get mobile_card_locations_path(card.id)

      expect(response.body).to include('Other Printings You Own')
    end

    it "leaves out another user's copies" do
      someone_else = create(:collection, user: create(:user), name: 'Not Mine')
      create(:collection_magic_card, collection: someone_else, magic_card: card, quantity: 1)

      get mobile_card_locations_path(card.id)

      expect(response.body).not_to include('Not Mine')
    end
  end

  context 'when signed out' do
    it 'is refused' do
      get mobile_card_locations_path(card.id)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
