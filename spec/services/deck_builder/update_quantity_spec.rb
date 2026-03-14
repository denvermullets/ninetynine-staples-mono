require 'rails_helper'

RSpec.describe DeckBuilder::UpdateQuantity, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }

  context 'when updating a staged card from a collection' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 4,
             foil_quantity: 2,
             staged: false,
             needed: false)
    end

    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: source_collection.id,
             staged: true,
             staged_quantity: 1,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: staged_card.id,
        quantity: 3,
        foil_quantity: 1
      )
    end

    it 'returns success' do
      expect(subject[:success]).to be true
    end

    it 'updates staged quantities' do
      subject
      staged_card.reload
      expect(staged_card.staged_quantity).to eq(3)
      expect(staged_card.staged_foil_quantity).to eq(1)
    end

    context 'when exceeding available quantity' do
      subject do
        described_class.call(
          deck: deck,
          collection_magic_card_id: staged_card.id,
          quantity: 10,
          foil_quantity: 0
        )
      end

      it 'returns an error' do
        expect(subject[:success]).to be false
        expect(subject[:error]).to include('available')
      end
    end
  end

  context 'when updating a non-staged (owned) card' do
    let!(:owned_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 2,
             foil_quantity: 1)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: owned_card.id,
        quantity: 4,
        foil_quantity: 2
      )
    end

    it 'updates the card quantities directly' do
      subject
      owned_card.reload
      expect(owned_card.quantity).to eq(4)
      expect(owned_card.foil_quantity).to eq(2)
    end
  end

  context 'when both quantities are zero' do
    let!(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 1,
             foil_quantity: 0)
    end

    subject do
      described_class.call(
        deck: deck,
        collection_magic_card_id: card.id,
        quantity: 0,
        foil_quantity: 0
      )
    end

    it 'deletes the card' do
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
    end
  end

  context 'when card does not exist' do
    it 'raises RecordNotFound' do
      expect {
        described_class.call(
          deck: deck,
          collection_magic_card_id: -1,
          quantity: 1,
          foil_quantity: 0
        )
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
