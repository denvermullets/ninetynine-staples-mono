require 'rails_helper'

RSpec.describe CollectionRecord::CreateOrUpdate, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user, total_value: 0, total_quantity: 0, total_foil_quantity: 0) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }
  let(:params) do
    {
      collection_id: collection.id,
      magic_card_id: magic_card.id,
      quantity: 2,
      foil_quantity: 1,
      buy_price: 4.0,
      sell_price: 6.0
    }
  end

  describe '#call' do
    context 'when creating a new record' do
      it 'creates a new collection magic card record' do
        service = described_class.new(collection_magic_card: nil, params: params)
        result = service.call

        collection.reload

        expect(result[:action]).to eq(:success)
        expect(CollectionMagicCard.count).to eq(1)
        expect(collection.total_value.to_f).to eq(20.0)
      end
    end

    context 'when updating an existing record' do
      let!(:collection_magic_card) do
        create(:collection_magic_card,
               collection: collection,
               magic_card: magic_card,
               quantity: 1,
               foil_quantity: 0)
      end

      before do
        # ensure collection starts at the correct total_value from previous action
        collection.update!(total_value: 5.0)
      end

      it 'updates the collection magic card quantities' do
        collection_magic_card.reload
        collection.reload

        service = described_class.new(collection_magic_card: collection_magic_card, params: params)
        result = service.call

        expect(result[:action]).to eq(:success)

        collection_magic_card.reload
        collection.reload

        expect(collection_magic_card.quantity).to eq(2)
        expect(collection_magic_card.foil_quantity).to eq(1)
        expect(collection.total_value.to_f).to eq(20.0)
      end
    end

    context 'when updating results in zero quantities' do
      let!(:collection_magic_card) do
        create(:collection_magic_card,
               collection: collection,
               magic_card: magic_card,
               quantity: 1,
               foil_quantity: 1)
      end

      before do
        # ensure correct starting value before deletion
        collection.update!(total_value: 15.0)
      end

      it 'removes the collection magic card record' do
        zero_params = params.merge(quantity: 0, foil_quantity: 0)
        service = described_class.new(collection_magic_card: collection_magic_card, params: zero_params)
        result = service.call

        expect(result[:action]).to eq(:delete)
        expect(CollectionMagicCard.exists?(collection_magic_card.id)).to be_falsey
        collection.reload
        expect(collection.total_value.to_f).to eq(0.0) # Ensure total value is updated
      end
    end
  end
end
