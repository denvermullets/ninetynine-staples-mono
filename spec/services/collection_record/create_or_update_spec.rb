require 'rails_helper'

RSpec.describe CollectionRecord::CreateOrUpdate, type: :service do
  let(:collection) { create(:collection) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }
  let(:params) do
    {
      collection_id: collection.id,
      magic_card_id: magic_card.id,
      quantity: quantity,
      foil_quantity: foil_quantity,
      card_uuid: 'test-uuid'
    }
  end

  subject { described_class.new(params:).call }

  context 'when adding a magic card to your collection' do
    let(:quantity) { 2 }
    let(:foil_quantity) { 1 }

    it 'creates a new CollectionMagicCard record' do
      expect { subject }.to change { CollectionMagicCard.count }.by(1)
    end

    it 'updates the collection totals correctly' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(2)
      expect(collection.total_foil_quantity).to eq(1)
      expect(collection.total_value).to eq((2 * 5.0) + (1 * 10.0))
    end

    it 'returns success with the card name' do
      result = subject
      expect(result).to eq({ action: :success, name: magic_card.name })
    end
  end

  context 'when updating an existing collection quantity' do
    let!(:collection_card) do
      create(:collection_magic_card,
             collection: collection,
             magic_card: magic_card,
             quantity: 1,
             foil_quantity: 1,
             card_uuid: 'test-uuid')
    end
    let(:quantity) { 3 }
    let(:foil_quantity) { 2 }

    it 'updates the CollectionMagicCard record' do
      subject
      collection_card.reload
      expect(collection_card.quantity).to eq(3)
      expect(collection_card.foil_quantity).to eq(2)
    end

    it 'updates the collection totals correctly' do
      # Since we're using increment!, we need to ensure the collection starts with the initial values
      collection.update!(
        total_quantity: 1,
        total_foil_quantity: 1,
        total_value: (1 * 5.0) + (1 * 10.0)
      )

      subject
      collection.reload
      expect(collection.total_quantity).to eq(3)
      expect(collection.total_foil_quantity).to eq(2)
      expect(collection.total_value).to eq((3 * 5.0) + (2 * 10.0))
    end

    it 'returns success with the card name' do
      result = subject
      expect(result).to eq({ action: :success, name: magic_card.name })
    end
  end

  context 'when both quantities are zero / deleting a card from your collection' do
    let!(:collection_card) do
      create(:collection_magic_card,
             collection: collection,
             magic_card: magic_card,
             quantity: 1,
             foil_quantity: 1,
             card_uuid: 'test-uuid')
    end
    let(:quantity) { 0 }
    let(:foil_quantity) { 0 }

    before do
      # Set initial collection totals
      collection.update!(
        total_quantity: 1,
        total_foil_quantity: 1,
        total_value: (1 * 5.0) + (1 * 10.0)
      )
    end

    it 'deletes the CollectionMagicCard record' do
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'updates collection totals correctly when card is removed' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(0)
      expect(collection.total_foil_quantity).to eq(0)
      expect(collection.total_value).to eq(0)
    end

    it 'returns delete action with the card name' do
      result = subject
      expect(result).to eq({ action: :delete, name: magic_card.name })
    end
  end
end
