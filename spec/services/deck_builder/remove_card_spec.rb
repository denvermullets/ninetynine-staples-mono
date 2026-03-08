require 'rails_helper'

RSpec.describe DeckBuilder::RemoveCard, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card) }

  subject { described_class.call(deck: deck, collection_magic_card_id: card.id) }

  context 'when removing a staged card' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: true,
             staged_quantity: 2,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'destroys the card' do
      card # force creation
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:message]).to eq('Card removed from deck')
    end
  end

  context 'when removing a needed card' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             needed: true,
             staged: false,
             quantity: 1,
             foil_quantity: 0)
    end

    it 'destroys the card' do
      card
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:message]).to eq('Needed card removed from deck')
    end
  end

  context 'when trying to remove a finalized card' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 1,
             foil_quantity: 0)
    end

    it 'does not destroy the card' do
      card
      expect { subject }.not_to(change { CollectionMagicCard.count })
    end

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to include('Cannot remove finalized cards')
    end
  end

  context 'when card does not exist in deck' do
    subject { described_class.call(deck: deck, collection_magic_card_id: -1) }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Card not found in deck')
    end
  end
end
