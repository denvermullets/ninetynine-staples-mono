require 'rails_helper'

RSpec.describe DeckBuilder::DeleteCard, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }

  subject { described_class.call(deck: deck, collection_magic_card_id: card.id) }

  context 'when deleting a finalized card' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: false,
             needed: false,
             quantity: 2,
             foil_quantity: 1)
    end

    before do
      deck.update!(total_quantity: 2, total_foil_quantity: 1, total_value: 20.0)
    end

    it 'destroys the card' do
      card
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:message]).to eq("#{magic_card.name} deleted from collection")
    end

    it 'decrements collection totals' do
      subject
      deck.reload
      expect(deck.total_quantity).to eq(0)
      expect(deck.total_foil_quantity).to eq(0)
    end
  end

  context 'when deleting a staged card' do
    let(:card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             staged: true,
             quantity: 0,
             foil_quantity: 0,
             staged_quantity: 1)
    end

    it 'destroys the card' do
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
