require 'rails_helper'

RSpec.describe DeckBuilder::UpdateStaged, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card) }

  context 'when updating staged quantities' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 4,
             foil_quantity: 2,
             proxy_quantity: 1,
             proxy_foil_quantity: 1,
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
        card_id: staged_card.id,
        quantities: { regular: 2, foil: 1, proxy: 0, proxy_foil: 0 }
      )
    end

    it 'returns success' do
      expect(subject[:success]).to be true
    end

    it 'updates all staged quantities' do
      subject
      staged_card.reload
      expect(staged_card.staged_quantity).to eq(2)
      expect(staged_card.staged_foil_quantity).to eq(1)
    end
  end

  context 'when all quantities are zero' do
    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
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
        card_id: staged_card.id,
        quantities: { regular: 0, foil: 0, proxy: 0, proxy_foil: 0 }
      )
    end

    it 'removes the card' do
      staged_card # force creation
      expect { subject }.to change { CollectionMagicCard.count }.by(-1)
    end

    it 'returns success with removed flag' do
      result = subject
      expect(result[:success]).to be true
      expect(result[:removed]).to be true
    end
  end

  context 'when quantities are negative' do
    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
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
        card_id: staged_card.id,
        quantities: { regular: -1, foil: 0, proxy: 0, proxy_foil: 0 }
      )
    end

    it 'returns a validation error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to eq('Quantities cannot be negative')
    end
  end

  context 'when exceeding source availability' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 2,
             foil_quantity: 0,
             proxy_quantity: 0,
             proxy_foil_quantity: 0,
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
        card_id: staged_card.id,
        quantities: { regular: 10, foil: 0, proxy: 0, proxy_foil: 0 }
      )
    end

    it 'returns an availability error' do
      expect(subject[:success]).to be false
      expect(subject[:error]).to include('available')
    end
  end

  context 'when card is planned (no source)' do
    let!(:planned_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: nil,
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
        card_id: planned_card.id,
        quantities: { regular: 5, foil: 0, proxy: 0, proxy_foil: 0 }
      )
    end

    it 'allows any quantity without source validation' do
      expect(subject[:success]).to be true
    end
  end
end
