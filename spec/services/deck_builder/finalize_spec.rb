require 'rails_helper'

RSpec.describe DeckBuilder::Finalize, type: :service do
  let(:user) { create(:user) }
  let(:deck) { create(:collection, user: user, collection_type: 'deck') }
  let(:source_collection) { create(:collection, user: user) }
  let(:magic_card) { create(:magic_card, normal_price: 5.0, foil_price: 10.0, card_uuid: 'finalize-uuid') }

  subject { described_class.call(deck: deck) }

  context 'when finalizing staged cards from an owned collection' do
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
             staged_quantity: 2,
             staged_foil_quantity: 1,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'returns success' do
      result = subject
      expect(result[:success]).to be true
    end

    it 'converts staged card to finalized' do
      subject
      staged_card.reload
      expect(staged_card.staged).to be false
      expect(staged_card.quantity).to eq(2)
      expect(staged_card.foil_quantity).to eq(1)
      expect(staged_card.staged_quantity).to eq(0)
      expect(staged_card.staged_foil_quantity).to eq(0)
      expect(staged_card.source_collection_id).to be_nil
    end

    it 'reduces the source collection card' do
      subject
      source_card.reload
      expect(source_card.quantity).to eq(2)
      expect(source_card.foil_quantity).to eq(1)
    end

    it 'updates deck totals' do
      subject
      deck.reload
      expect(deck.total_quantity).to eq(2)
      expect(deck.total_foil_quantity).to eq(1)
    end

    it 'updates source collection totals' do
      subject
      source_collection.reload
      expect(source_collection.total_quantity).to eq(2)
      expect(source_collection.total_foil_quantity).to eq(1)
    end
  end

  context 'when staged card fully consumes source' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 1,
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

    it 'destroys the source card' do
      expect { subject }.to change { source_collection.collection_magic_cards.count }.by(-1)
    end
  end

  context 'when there are planned cards (no source)' do
    let!(:planned_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: nil,
             staged: true,
             staged_quantity: 3,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'counts planned cards as needed' do
      result = subject
      expect(result[:success]).to be true
      expect(result[:cards_needed]).to eq(3)
      expect(result[:cards_moved]).to eq(0)
    end

    it 'does not finalize planned cards' do
      subject
      planned_card.reload
      expect(planned_card.staged).to be true
    end
  end

  context 'when source no longer has enough cards' do
    let!(:source_card) do
      create(:collection_magic_card,
             collection: source_collection,
             magic_card: magic_card,
             quantity: 1,
             foil_quantity: 0,
             staged: false,
             needed: false)
    end

    let!(:staged_card) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: source_collection.id,
             staged: true,
             staged_quantity: 5,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'returns an error about insufficient cards' do
      result = subject
      expect(result[:success]).to be false
      expect(result[:error]).to include('available')
    end
  end

  context 'when no staged cards exist' do
    it 'returns an error' do
      result = subject
      expect(result[:success]).to be false
      expect(result[:error]).to eq('No staged cards to finalize')
    end
  end

  context 'with mixed owned and planned cards' do
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

    let(:other_boxset) { create(:boxset) }
    let(:other_card) {
      create(:magic_card, card_uuid: 'other-uuid', normal_price: 3.0, foil_price: 6.0, boxset: other_boxset)
    }

    let!(:owned_staged) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: magic_card,
             source_collection_id: source_collection.id,
             staged: true,
             staged_quantity: 2,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    let!(:planned_staged) do
      create(:collection_magic_card,
             collection: deck,
             magic_card: other_card,
             source_collection_id: nil,
             staged: true,
             staged_quantity: 1,
             staged_foil_quantity: 0,
             staged_proxy_quantity: 0,
             staged_proxy_foil_quantity: 0,
             quantity: 0,
             foil_quantity: 0)
    end

    it 'finalizes owned cards and counts planned cards' do
      result = subject
      expect(result[:success]).to be true
      expect(result[:cards_needed]).to eq(1)
    end
  end
end
