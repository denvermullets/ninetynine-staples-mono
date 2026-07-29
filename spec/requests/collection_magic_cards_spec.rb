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
end
