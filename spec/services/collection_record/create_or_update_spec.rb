require 'rails_helper'

RSpec.describe CollectionRecord::CreateOrUpdate, type: :service do
  let(:collection) { create(:collection) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }
  let(:params) do
    {
      collection_id: collection.id,
      magic_card_id: magic_card.id,
      quantity: quantity,
      foil_quantity: foil_quantity
    }
  end

  subject { described_class.new(params:).call }

  context 'when creating a new collection magic card' do
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
  end

  context 'when updating an existing collection magic card' do
    let!(:collection_card) {
      create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: 1, foil_quantity: 1)
    }
    let(:quantity) { 3 }
    let(:foil_quantity) { 2 }

    it 'updates the CollectionMagicCard record' do
      subject
      collection_card.reload
      expect(collection_card.quantity).to eq(3)
      expect(collection_card.foil_quantity).to eq(2)
    end

    it 'updates the collection totals correctly' do
      subject
      collection.reload
      expect(collection.total_quantity).to eq(3)
      expect(collection.total_foil_quantity).to eq(2)
      expect(collection.total_value).to eq((3 * 5.0) + (2 * 10.0))
    end
  end

  context 'when both quantities are zero' do
    let!(:collection_card) {
      create(:collection_magic_card, collection: collection, magic_card: magic_card, quantity: 1, foil_quantity: 1)
    }
    let(:quantity) { 0 }
    let(:foil_quantity) { 0 }

    it 'deletes the CollectionMagicCard record' do
      expect { subject }.to change { CollectionMagicCard.exists?(collection_card.id) }.to(false)
    end

    # expect { subject }.to change { CollectionMagicCard.count }.by(-1)

    it 'sets collection totals to zero when the last card is removed' do
      subject
      collection.reload
      expect(collection.collection_magic_cards.count).to eq(0) # Ensure no records remain
      expect(collection.total_quantity).to eq(0)
      expect(collection.total_foil_quantity).to eq(0)
      expect(collection.total_value).to eq(0)
    end
  end
end
