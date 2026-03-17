require 'rails_helper'

RSpec.describe DeckBuilder::DeleteCard, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }

  subject { described_class.call(deck: deck, collection_magic_card_id: card.id) }

  context 'when card has multiple copies' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 3,
             foil_quantity: 0)
    end

    it 'destroys the record entirely' do
      card
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success with card name' do
      result = subject
      expect(result[:success]).to be true
      expect(result[:message]).to include('deleted from collection')
    end

    it 'returns removed_oracle_id' do
      result = subject
      expect(result[:removed_oracle_id]).to eq(magic_card.scryfall_oracle_id)
    end
  end

  context 'when card has 1 copy' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 1,
             foil_quantity: 0)
    end

    it 'destroys the record' do
      card
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
    end
  end

  context 'when card does not exist' do
    subject { described_class.call(deck: deck, collection_magic_card_id: -1) }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Card not found in deck')
    end
  end
end
