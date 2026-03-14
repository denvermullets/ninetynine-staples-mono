require 'rails_helper'

RSpec.describe CollectionImporter::Archidekt, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, collection_type: 'collection') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_uuid: SecureRandom.uuid) }
  let(:scryfall_id) { SecureRandom.uuid }

  before do
    MagicCardIdentifier.create!(magic_card: magic_card, scryfall_id: scryfall_id)
  end

  describe '#call' do
    context 'with a normal card' do
      let(:row_data) do
        { scryfall_id: scryfall_id, quantity: 3, finish: 'Normal', name: 'Lightning Bolt', edition_code: '2XM' }
      end

      it 'returns success' do
        result = described_class.call(row_data: row_data, collection: collection)
        expect(result[:action]).to eq(:success)
      end

      it 'creates a collection magic card' do
        expect {
          described_class.call(row_data: row_data, collection: collection)
        }.to change { collection.collection_magic_cards.count }.by(1)
      end

      it 'sets normal quantity' do
        described_class.call(row_data: row_data, collection: collection)
        cmc = collection.collection_magic_cards.find_by(magic_card: magic_card)
        expect(cmc.quantity).to eq(3)
        expect(cmc.foil_quantity).to eq(0)
      end

      it 'updates collection totals' do
        described_class.call(row_data: row_data, collection: collection)
        collection.reload
        expect(collection.total_quantity).to eq(3)
      end
    end

    context 'with a foil card' do
      let(:row_data) do
        { scryfall_id: scryfall_id, quantity: 2, finish: 'Foil', name: 'Lightning Bolt', edition_code: '2XM' }
      end

      it 'sets foil quantity' do
        described_class.call(row_data: row_data, collection: collection)
        cmc = collection.collection_magic_cards.find_by(magic_card: magic_card)
        expect(cmc.quantity).to eq(0)
        expect(cmc.foil_quantity).to eq(2)
      end

      it 'updates collection foil totals' do
        described_class.call(row_data: row_data, collection: collection)
        collection.reload
        expect(collection.total_foil_quantity).to eq(2)
      end
    end

    context 'when card not found' do
      let(:row_data) do
        { scryfall_id: SecureRandom.uuid, quantity: 1, finish: 'Normal', name: 'Unknown Card', edition_code: 'UNK' }
      end

      it 'returns skipped' do
        result = described_class.call(row_data: row_data, collection: collection)
        expect(result[:action]).to eq(:skipped)
        expect(result[:name]).to eq('Unknown Card')
      end

      it 'does not create a collection magic card' do
        expect {
          described_class.call(row_data: row_data, collection: collection)
        }.not_to(change { CollectionMagicCard.count })
      end
    end

    context 'when importing same card twice' do
      let(:row_data) do
        { scryfall_id: scryfall_id, quantity: 2, finish: 'Normal', name: 'Lightning Bolt', edition_code: '2XM' }
      end

      it 'increments quantity' do
        described_class.call(row_data: row_data, collection: collection)
        described_class.call(row_data: row_data, collection: collection)

        cmc = collection.collection_magic_cards.find_by(magic_card: magic_card)
        expect(cmc.quantity).to eq(4)
      end
    end
  end
end
