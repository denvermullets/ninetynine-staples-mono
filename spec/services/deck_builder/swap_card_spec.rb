require 'rails_helper'

RSpec.describe DeckBuilder::SwapCard, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0) }

  let!(:needed_card) do
    create(:collection_magic_card,
           collection: deck,
           magic_card: magic_card,
           needed: true,
           staged: false,
           quantity: 1,
           foil_quantity: 0)
  end

  let!(:source_card) do
    create(:collection_magic_card,
           collection: source_collection,
           magic_card: magic_card,
           quantity: 3,
           foil_quantity: 1,
           staged: false,
           needed: false)
  end

  subject do
    described_class.call(
      deck: deck,
      collection_magic_card_id: needed_card.id,
      source_collection_id: source_collection.id
    )
  end

  context 'when swapping a needed card with a specific source' do
    it 'returns success' do
      expect(subject[:success]).to be true
      expect(subject[:card_name]).to eq(magic_card.name)
    end

    it 'marks the deck card as no longer needed' do
      subject
      needed_card.reload
      expect(needed_card.needed).to be false
    end

    it 'reduces the source card quantity' do
      subject
      source_card.reload
      expect(source_card.quantity).to eq(2)
    end

    it 'updates collection totals' do
      subject
      source_collection.reload
      deck.reload
      expect(source_collection.total_quantity).to eq(2)
    end
  end

  context 'when source does not have enough copies' do
    before do
      source_card.update!(quantity: 0, foil_quantity: 0)
    end

    it 'returns an error' do
      result = subject
      expect(result[:success]).to be false
      expect(result[:error]).to include('Not enough copies')
    end
  end

  context 'when no source is available' do
    subject do
      described_class.call(deck: deck, collection_magic_card_id: needed_card.id)
    end

    before { source_card.destroy! }

    it 'returns an error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('No available copies found')
    end
  end

  context 'when source card is fully consumed' do
    before do
      source_card.update!(quantity: 1, foil_quantity: 0, proxy_quantity: 0, proxy_foil_quantity: 0)
    end

    it 'destroys the source card' do
      expect { subject }.to change { source_collection.collection_magic_cards.count }.by(-1)
    end
  end
end
