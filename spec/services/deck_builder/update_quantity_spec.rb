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

  context 'when updating a finalized card' do
    let!(:owned_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 2,
             foil_quantity: 1)
    end

    def update_to(quantity, foil_quantity)
      described_class.call(
        deck: deck,
        collection_magic_card_id: owned_card.id,
        quantity: quantity,
        foil_quantity: foil_quantity
      )
    end

    it 'refuses, since the copies have to come from or go to a real location' do
      result = update_to(4, 2)

      expect(result[:success]).to be false
      expect(result[:error]).to include('collection view')
    end

    it 'leaves the quantities alone' do
      update_to(4, 2)
      owned_card.reload
      expect(owned_card.quantity).to eq(2)
      expect(owned_card.foil_quantity).to eq(1)
    end

    it 'does not delete the card when set to zero' do
      expect { update_to(0, 0) }.not_to(change { CollectionMagicCard.count })
    end
  end

  context 'when updating a needed card' do
    let!(:needed_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: true,
             quantity: 1,
             foil_quantity: 0)
    end

    def update_to(quantity, foil_quantity)
      described_class.call(
        deck: deck,
        collection_magic_card_id: needed_card.id,
        quantity: quantity,
        foil_quantity: foil_quantity
      )
    end

    it 'updates the card quantities directly' do
      update_to(3, 0)
      expect(needed_card.reload.quantity).to eq(3)
    end

    it 'deletes the card when both quantities are zero' do
      result = update_to(0, 0)

      expect(result[:success]).to be true
      expect(CollectionMagicCard.exists?(needed_card.id)).to be false
    end
  end

  context 'when card does not exist' do
    it 'returns an error' do
      result = described_class.call(
        deck: deck,
        collection_magic_card_id: -1,
        quantity: 1,
        foil_quantity: 0
      )
      expect(result[:success]).to be false
      expect(result[:error]).to eq('Card not found')
    end
  end
end
