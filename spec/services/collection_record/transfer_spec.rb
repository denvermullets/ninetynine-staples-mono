require 'rails_helper'

RSpec.describe CollectionRecord::Transfer, type: :service do
  let(:user) { create(:user) }
  let(:from_collection) {
    create(:collection, user: user, total_quantity: 4, total_foil_quantity: 1, total_value: 30.0)
  }
  let(:to_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_uuid: 'transfer-uuid') }

  let!(:source_card) do
    create(:collection_magic_card,
           collection: from_collection,
           magic_card: magic_card,
           card_uuid: 'transfer-uuid',
           quantity: 4,
           foil_quantity: 1,
           proxy_quantity: 0,
           proxy_foil_quantity: 0)
  end

  let(:params) do
    {
      magic_card_id: magic_card.id,
      from_collection_id: from_collection.id,
      to_collection_id: to_collection.id,
      quantity: quantity,
      foil_quantity: foil_quantity,
      proxy_quantity: 0,
      proxy_foil_quantity: 0
    }
  end

  subject { described_class.call(params: params) }

  context 'when transferring cards' do
    let(:quantity) { 2 }
    let(:foil_quantity) { 1 }

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:name]).to eq(magic_card.name)
    end

    it 'reduces source card quantity' do
      subject
      source_card.reload
      expect(source_card.quantity).to eq(2)
      expect(source_card.foil_quantity).to eq(0)
    end

    it 'creates or updates destination card' do
      expect { subject }.to change {
        to_collection.collection_magic_cards.count
      }.by(1)

      dest_card = to_collection.collection_magic_cards.first
      expect(dest_card.quantity).to eq(2)
      expect(dest_card.foil_quantity).to eq(1)
    end

    it 'updates source collection totals' do
      subject
      from_collection.reload
      expect(from_collection.total_quantity).to eq(2)
      expect(from_collection.total_foil_quantity).to eq(0)
    end

    it 'updates destination collection totals' do
      subject
      to_collection.reload
      expect(to_collection.total_quantity).to eq(2)
      expect(to_collection.total_foil_quantity).to eq(1)
    end
  end

  context 'when transferring all cards' do
    let(:quantity) { 4 }
    let(:foil_quantity) { 1 }

    it 'destroys the source card' do
      expect { subject }.to change { from_collection.collection_magic_cards.count }.by(-1)
    end
  end

  context 'when transferring nothing' do
    let(:quantity) { 0 }
    let(:foil_quantity) { 0 }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('No cards to transfer')
    end
  end

  context 'when source does not have enough cards' do
    let(:quantity) { 10 }
    let(:foil_quantity) { 0 }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Not enough cards to transfer')
    end
  end
end
