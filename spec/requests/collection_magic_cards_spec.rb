require 'rails_helper'

RSpec.describe 'CollectionMagicCards', type: :request do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card) }

  describe 'GET /collection_magic_cards/quantity' do
    let!(:first_printing) do
      create(:collection_magic_card, collection: collection, magic_card: magic_card,
                                     card_uuid: 'uuid-one', quantity: 2, foil_quantity: 1)
    end
    let!(:second_printing) do
      create(:collection_magic_card, collection: collection, magic_card: magic_card,
                                     card_uuid: 'uuid-two', quantity: 7, foil_quantity: 0)
    end

    it 'returns every variant for the collection' do
      get collection_quantity_path, params: { collection_id: collection.id, magic_card_id: magic_card.id }

      expect(response.parsed_body.keys)
        .to match_array(%w[quantity foil_quantity proxy_quantity proxy_foil_quantity])
    end

    it 'narrows to the requested printing when a card_uuid is given' do
      get collection_quantity_path,
          params: { collection_id: collection.id, magic_card_id: magic_card.id, card_uuid: 'uuid-two' }

      expect(response.parsed_body['quantity']).to eq(7)
      expect(response.parsed_body['foil_quantity']).to eq(0)
    end

    it 'zeroes out when the card is not in the collection' do
      get collection_quantity_path,
          params: { collection_id: collection.id, magic_card_id: magic_card.id, card_uuid: 'nope' }

      expect(response.parsed_body.values).to all(eq(0))
    end
  end

  describe 'POST /collection_magic_cards/adjust' do
    let(:oracle_id) { SecureRandom.uuid }
    let(:expanded_card) { create(:magic_card, scryfall_oracle_id: oracle_id) }
    let(:other_printing) do
      create(:magic_card, scryfall_oracle_id: oracle_id, boxset: create(:boxset))
    end

    before { post login_path, params: { email: user.email, password: 'password123' } }

    it 'refreshes the frame of the card that was adjusted' do
      post adjust_collection_magic_cards_path,
           params: { collection_id: collection.id, magic_card_id: expanded_card.id, quantity: 3 },
           as: :turbo_stream

      expect(response.body).to include("card_details_#{expanded_card.id}")
    end

    it 'refreshes the expanded row when adjusting a different printing' do
      post adjust_collection_magic_cards_path,
           params: { collection_id: collection.id, magic_card_id: other_printing.id, quantity: 3,
                     refresh_card_id: expanded_card.id, show_other_printings: true },
           as: :turbo_stream

      expect(response.body).to include("card_details_#{expanded_card.id}")
      expect(response.body).not_to include("card_details_#{other_printing.id}")
    end

    it 'renders the other printings table with a hover preview on that table only' do
      post adjust_collection_magic_cards_path,
           params: { collection_id: collection.id, magic_card_id: other_printing.id, quantity: 3,
                     refresh_card_id: expanded_card.id, show_other_printings: true },
           as: :turbo_stream

      expect(response.body).to include('Other Printings You Own')
      expect(response.body.scan('data-controller="card-hover"').size).to eq(1)
    end

    it 'omits the other printings table when the flag is not set' do
      create(:collection_magic_card, collection: collection, magic_card: other_printing)

      post adjust_collection_magic_cards_path,
           params: { collection_id: collection.id, magic_card_id: expanded_card.id, quantity: 3 },
           as: :turbo_stream

      expect(response.body).not_to include('Other Printings You Own')
    end
  end
end
